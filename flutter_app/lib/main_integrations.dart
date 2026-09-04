part of 'main.dart';

class IntegrationsPanel extends StatelessWidget {
  const IntegrationsPanel({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final NeoAgentController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: <Widget>[
        if (!embedded) ...<Widget>[
          _PageTitle(
            title: 'Integrations',
            subtitle:
                'Connect and manage official integrations separately from reusable skills.',
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: OfficialIntegrationsTab(controller: controller)),
      ],
    );
    if (embedded) {
      return body;
    }
    return Padding(padding: _pagePadding(context), child: body);
  }
}

class OfficialIntegrationsTab extends StatelessWidget {
  const OfficialIntegrationsTab({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final visibleIntegrations =
        controller.officialIntegrations
            .where(
              (item) =>
                  item.env.configured ||
                  item.env.setupMode == 'user' ||
                  item.isConnected,
            )
            .toList()
          ..sort(_compareOfficialIntegrationItems);

    if (visibleIntegrations.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No official integrations are available yet.',
              style: TextStyle(color: _textSecondary),
            ),
          ),
        ),
      );
    }

    final connectedIntegrations = visibleIntegrations
        .where((item) => item.isConnected)
        .toList();
    final availableIntegrations = visibleIntegrations
        .where(
          (item) =>
              !item.isConnected &&
              (item.env.configured || item.env.setupMode == 'user'),
        )
        .toList();

    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (connectedIntegrations.isNotEmpty) ...[
            const _IntegrationSectionTitle(title: 'Connected'),
            ...connectedIntegrations.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < connectedIntegrations.length - 1 ? 12 : 0,
                ),
                child: _buildIntegrationCard(context, entry.value),
              ),
            ),
          ],
          if (connectedIntegrations.isNotEmpty &&
              availableIntegrations.isNotEmpty)
            const SizedBox(height: 24),
          if (availableIntegrations.isNotEmpty) ...[
            const _IntegrationSectionTitle(title: 'Available'),
            ...availableIntegrations.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < availableIntegrations.length - 1 ? 12 : 0,
                ),
                child: _buildIntegrationCard(context, entry.value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntegrationCard(
    BuildContext context,
    OfficialIntegrationItem item,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.isConnected ? _accentMuted : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _OfficialIntegrationIcon(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusPill(
                          label: item.statusLabel,
                          color: item.isConnected
                              ? _success
                              : item.hasExpiredAccounts
                              ? _warning
                              : item.env.configured
                              ? _info
                              : _warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(color: _textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetaPill(
                          label: '${item.connection.accountCount} accounts',
                          icon: Icons.alternate_email_rounded,
                        ),
                        _MetaPill(
                          label: '${item.connection.appCount} apps active',
                          icon: Icons.apps_rounded,
                        ),
                        _MetaPill(
                          label: '${item.availableToolCount} tools',
                          icon: Icons.build_outlined,
                        ),
                        _MetaPill(
                          label: item.memoryCoverage.supported
                              ? 'Memory ${item.memoryCoverage.statusLabel}'
                              : 'No memory sync',
                          icon: Icons.psychology_alt_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      !item.env.configured
                          ? item.env.summary
                          : item.hasExpiredAccounts
                          ? item.id == 'google_workspace'
                                ? 'One or more accounts expired. Reconnect to restore access. If this keeps happening, your Google Cloud OAuth app may be in Testing mode — publish it to Production in Google Cloud Console to get long-lived tokens.'
                                : 'One or more accounts expired. Reconnect the affected account to restore tool access.'
                          : !item.supportsMultipleAccounts && item.isConnected
                          ? 'This integration currently supports one connected account per agent. Re-open setup to replace it.'
                          : item.isConnected
                          ? 'Connect as many accounts as you want. Each app can use a different account.'
                          : ((item.connectPrompt ?? '').trim().isNotEmpty
                                ? item.connectPrompt!.trim()
                                : 'Connect app accounts individually so the AI can use the right account for each official integration.'),
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...item.apps.map(
            (app) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OfficialIntegrationAppCard(
                controller: controller,
                provider: item,
                app: app,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openOfficialIntegrationSetupDialog(
  BuildContext context,
  NeoAgentController controller,
  String providerId,
) {
  switch (providerId) {
    case 'bitwarden':
      _showBitwardenSetupDialog(context, controller);
      return;
    case 'home_assistant':
      _showHomeAssistantSetupDialog(context, controller);
      return;
    case 'neoarchive':
      _showNeoArchiveSetupDialog(context, controller);
      return;
    case 'neorecall':
      _showNeoRecallSetupDialog(context, controller);
      return;
    case 'trello':
      _showTrelloSetupDialog(context, controller);
      return;
  }
}

Future<void> _showBitwardenBindingDialog(
  BuildContext context,
  NeoAgentController controller, {
  required int connectionId,
}) async {
  List<Map<String, dynamic>> items;
  try {
    items = await controller.fetchBitwardenItems();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }
  if (items.isEmpty || !context.mounted) return;
  String itemId = items.first['id']?.toString() ?? '';
  var usageType = 'browser';
  var saving = false;
  var errorText = '';
  final aliasController = TextEditingController();
  final originController = TextEditingController(
    text: ((items.first['origins'] as List?)?.firstOrNull)?.toString() ?? '',
  );
  final pathController = TextEditingController(text: '/');
  final headerController = TextEditingController(text: 'X-API-Key');
  var authType = 'bearer';
  var secretField = 'login.password';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final selected = items.firstWhere(
          (item) => item['id']?.toString() == itemId,
          orElse: () => items.first,
        );
        final customFields = (selected['fields'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (field) => (
                field['id']?.toString().isNotEmpty == true
                    ? field['id'].toString()
                    : field['name'].toString(),
                field['name']?.toString() ?? 'Custom field',
              ),
            )
            .toList();
        final secretOptions = <(String, String)>[
          ('login.password', 'Login password'),
          ...customFields,
        ];
        if (!secretOptions.any((entry) => entry.$1 == secretField)) {
          secretField = secretOptions.first.$1;
        }
        return AlertDialog(
          title: const Text('Add credential binding'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: itemId,
                    decoration: const InputDecoration(
                      labelText: 'Bitwarden item',
                      border: OutlineInputBorder(),
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item['id']?.toString(),
                            child: Text(item['name']?.toString() ?? 'Untitled'),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            itemId = value ?? itemId;
                            final item = items.firstWhere(
                              (candidate) =>
                                  candidate['id']?.toString() == itemId,
                            );
                            final origins = item['origins'] as List?;
                            if (origins?.isNotEmpty == true) {
                              originController.text = origins!.first.toString();
                            }
                          }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aliasController,
                    decoration: const InputDecoration(
                      labelText: 'Agent-visible name',
                      hintText: 'Work account',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: usageType,
                    decoration: const InputDecoration(
                      labelText: 'Use for',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'browser',
                        child: Text('Browser login'),
                      ),
                      DropdownMenuItem(
                        value: 'http',
                        child: Text('API request'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) =>
                              setState(() => usageType = value ?? usageType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: originController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: usageType == 'browser'
                          ? 'Allowed HTTPS origin'
                          : 'API HTTPS origin',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (usageType == 'http') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pathController,
                      decoration: const InputDecoration(
                        labelText: 'Allowed path prefix',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: authType,
                      decoration: const InputDecoration(
                        labelText: 'Authentication',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'bearer',
                          child: Text('Bearer token'),
                        ),
                        DropdownMenuItem(
                          value: 'basic',
                          child: Text('Basic authentication'),
                        ),
                        DropdownMenuItem(
                          value: 'header',
                          child: Text('Custom header'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => authType = value ?? authType),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: secretField,
                      decoration: const InputDecoration(
                        labelText: 'Secret field',
                        border: OutlineInputBorder(),
                      ),
                      items: secretOptions
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.$1,
                              child: Text(entry.$2),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(
                              () => secretField = value ?? secretField,
                            ),
                    ),
                    if (authType == 'header') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: headerController,
                        decoration: const InputDecoration(
                          labelText: 'Header name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(errorText, style: TextStyle(color: _danger)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() {
                        saving = true;
                        errorText = '';
                      });
                      try {
                        await controller.createCredentialBinding(
                          <String, dynamic>{
                            'connectionId': connectionId,
                            'alias': aliasController.text.trim(),
                            'usageType': usageType,
                            'itemId': itemId,
                            if (usageType == 'browser')
                              'origins': <String>[originController.text.trim()],
                            if (usageType == 'http') ...<String, dynamic>{
                              'origin': originController.text.trim(),
                              'pathPrefix': pathController.text.trim(),
                              'methods': const [
                                'GET',
                                'POST',
                                'PUT',
                                'PATCH',
                                'DELETE',
                              ],
                              'authType': authType,
                              'secretField': secretField,
                              if (authType == 'basic')
                                'usernameField': 'login.username',
                              if (authType == 'header')
                                'headerName': headerController.text.trim(),
                            },
                          },
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (_) {
                        setState(() {
                          errorText =
                              controller.errorMessage ??
                              'Could not create binding.';
                          saving = false;
                        });
                      }
                    },
              child: Text(saving ? 'Adding...' : 'Add binding'),
            ),
          ],
        );
      },
    ),
  );
  aliasController.dispose();
  originController.dispose();
  pathController.dispose();
  headerController.dispose();
}

Future<void> _showBitwardenSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> config;
  List<Map<String, dynamic>> bindings;
  try {
    config = await controller.getOfficialIntegrationConfig('bitwarden');
    bindings = await controller.fetchCredentialBindings();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }
  var unlocked = config['unlocked'] == true;
  var persistSession = true;
  var twoStepMethod = '';
  var busy = false;
  var errorText = '';
  final serverController = TextEditingController(
    text: config['serverUrl']?.toString() ?? 'https://vault.bitwarden.com',
  );
  final emailController = TextEditingController(
    text: config['email']?.toString() ?? '',
  );
  final masterPasswordController = TextEditingController();
  final twoStepCodeController = TextEditingController();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Bitwarden credential broker'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in with the same email and master password you use in Bitwarden. The master password and two-step code are used only for sign-in and are never stored or sent to the AI.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serverController,
                  decoration: const InputDecoration(
                    labelText: 'Bitwarden server',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Account email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  unlocked
                      ? config['persistent'] == true
                            ? 'Vault connected and available after restart'
                            : 'Vault connected for this session'
                      : 'Vault locked',
                  style: TextStyle(color: unlocked ? _success : _textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: masterPasswordController,
                        obscureText: true,
                        enabled: !busy && !unlocked,
                        decoration: const InputDecoration(
                          labelText: 'Master password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                if (unlocked) {
                                  await controller.lockBitwarden();
                                  unlocked = false;
                                  config = <String, dynamic>{
                                    ...config,
                                    'unlocked': false,
                                    'persistent': false,
                                  };
                                } else {
                                  await controller
                                      .saveOfficialIntegrationConfig(
                                        'bitwarden',
                                        config: <String, dynamic>{
                                          'serverUrl': serverController.text
                                              .trim(),
                                          'email': emailController.text.trim(),
                                        },
                                      );
                                  config = await controller.unlockBitwarden(
                                    masterPasswordController.text,
                                    persistSession: persistSession,
                                    twoStepMethod: twoStepMethod,
                                    twoStepCode: twoStepCodeController.text,
                                  );
                                  masterPasswordController.clear();
                                  twoStepCodeController.clear();
                                  unlocked = true;
                                }
                                setState(() {});
                              } catch (_) {
                                setState(
                                  () => errorText =
                                      controller.errorMessage ??
                                      'Vault operation failed.',
                                );
                              } finally {
                                setState(() => busy = false);
                              }
                            },
                      child: Text(unlocked ? 'Lock' : 'Connect'),
                    ),
                  ],
                ),
                if (!unlocked) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: twoStepMethod,
                    decoration: const InputDecoration(
                      labelText: 'Two-step login (only if enabled)',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text('Not needed'),
                      ),
                      DropdownMenuItem<String>(
                        value: '0',
                        child: Text('Authenticator app'),
                      ),
                      DropdownMenuItem<String>(
                        value: '1',
                        child: Text('Email code'),
                      ),
                      DropdownMenuItem<String>(
                        value: '3',
                        child: Text('YubiKey OTP'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => twoStepMethod = value ?? ''),
                  ),
                  if (twoStepMethod.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: twoStepCodeController,
                      enabled: !busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current two-step login code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: persistSession,
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => persistSession = value ?? true),
                    title: const Text('Keep the vault available'),
                    subtitle: const Text(
                      'Stores only the Bitwarden session key encrypted on this server, so connections survive restarts. You can lock it at any time.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Credential bindings',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          !unlocked || config['connectionId'] == null || busy
                          ? null
                          : () async {
                              await _showBitwardenBindingDialog(
                                dialogContext,
                                controller,
                                connectionId: (config['connectionId'] as num)
                                    .toInt(),
                              );
                              bindings = await controller
                                  .fetchCredentialBindings();
                              setState(() {});
                            },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (bindings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No bindings yet.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                else
                  ...bindings.map(
                    (binding) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(binding['alias']?.toString() ?? 'Credential'),
                      subtitle: Text(binding['usageType']?.toString() ?? ''),
                      trailing: IconButton(
                        tooltip: 'Delete binding',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: busy
                            ? null
                            : () async {
                                await controller.deleteCredentialBinding(
                                  binding['id'].toString(),
                                );
                                bindings = await controller
                                    .fetchCredentialBindings();
                                setState(() {});
                              },
                      ),
                    ),
                  ),
                if (errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(errorText, style: TextStyle(color: _danger)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (config['configured'] == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await controller.clearOfficialIntegrationConfig(
                          'bitwarden',
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (_) {
                        setState(() {
                          errorText =
                              controller.errorMessage ??
                              'Could not disconnect Bitwarden.';
                          busy = false;
                        });
                      }
                    },
              child: const Text('Disconnect'),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      errorText = '';
                    });
                    try {
                      await controller.saveOfficialIntegrationConfig(
                        'bitwarden',
                        config: <String, dynamic>{
                          'serverUrl': serverController.text.trim(),
                          'email': emailController.text.trim(),
                        },
                      );
                      config = await controller.getOfficialIntegrationConfig(
                        'bitwarden',
                      );
                      setState(() {});
                    } catch (_) {
                      setState(
                        () => errorText =
                            controller.errorMessage ??
                            'Could not save Bitwarden setup.',
                      );
                    } finally {
                      setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Saving...' : 'Save account'),
          ),
        ],
      ),
    ),
  );
  serverController.dispose();
  emailController.dispose();
  masterPasswordController.dispose();
  twoStepCodeController.dispose();
}

Future<void> _showNeoRecallSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig('neorecall');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }
  final savedBaseUrl = existing['baseUrl']?.toString() ?? '';
  final accountCount = (existing['accountCount'] as num?)?.toInt() ?? 0;
  final connected = existing['hasConnectedAccount'] == true || accountCount > 0;
  final baseUrlController = TextEditingController(text: savedBaseUrl);
  var errorText = '';
  var busy = false;

  Future<void> save(
    StateSetter setState,
    BuildContext dialogContext, {
    required bool connect,
  }) async {
    setState(() {
      errorText = '';
      busy = true;
    });
    try {
      final baseUrl = baseUrlController.text.trim();
      if (baseUrl.isEmpty) {
        setState(() {
          errorText = 'NeoRecall backend URL is required.';
          busy = false;
        });
        return;
      }
      await controller.saveOfficialIntegrationConfig(
        'neorecall',
        config: <String, dynamic>{'baseUrl': baseUrl},
      );
      if (connect) {
        await controller.connectOfficialIntegration(
          'neorecall',
          appId: 'recall',
        );
        if ((controller.errorMessage ?? '').trim().isNotEmpty) {
          setState(() {
            errorText = controller.errorMessage!;
            busy = false;
          });
          return;
        }
      }
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    } catch (_) {
      setState(() {
        errorText =
            controller.errorMessage ?? 'Could not save NeoRecall setup.';
        busy = false;
      });
    }
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('NeoRecall Setup'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Connect your self-hosted NeoRecall server. NeoAgent receives read-only access to local search, memories, and transcript evidence after you approve the OAuth screen.',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Use a NeoRecall URL the NeoAgent server can reach. NeoAgent\'s PUBLIC_URL must also be reachable from this browser for the OAuth callback.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const _IntegrationSetupStatusItem(
                label: 'Connection Method',
                status: 'OAuth with PKCE',
                isConnected: true,
              ),
              const SizedBox(height: 12),
              _IntegrationSetupStatusItem(
                label: 'Connected NeoRecall User',
                status: connected
                    ? '$accountCount ${accountCount == 1 ? 'connected user' : 'connected users'}'
                    : 'Not connected',
                isConnected: connected,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'NeoRecall Backend URL',
                  hintText: 'https://recall.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Local and private-network URLs are supported when the NeoAgent server can reach them. Audio is never exposed to NeoAgent.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              if (errorText.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(errorText, style: TextStyle(color: _danger, fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (savedBaseUrl.isNotEmpty)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirm =
                          await showDialog<bool>(
                            context: dialogContext,
                            builder: (context) => AlertDialog(
                              title: const Text('Disconnect NeoRecall?'),
                              content: const Text(
                                'This removes the NeoRecall backend URL and all connected NeoRecall accounts for this agent.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirm) return;
                      setState(() {
                        busy = true;
                        errorText = '';
                      });
                      try {
                        await controller.clearOfficialIntegrationConfig(
                          'neorecall',
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (_) {
                        setState(() {
                          errorText =
                              controller.errorMessage ??
                              'Could not disconnect NeoRecall.';
                          busy = false;
                        });
                      }
                    },
              child: const Text('Disconnect'),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => save(setState, dialogContext, connect: false),
            child: const Text('Save Only'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () => save(setState, dialogContext, connect: true),
            child: Text(
              busy
                  ? 'Working...'
                  : connected
                  ? 'Connect Another Account'
                  : 'Save & Connect',
            ),
          ),
        ],
      ),
    ),
  );
  baseUrlController.dispose();
}

Future<void> _showNeoArchiveSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig('neoarchive');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }
  final savedBaseUrl = existing['baseUrl']?.toString() ?? '';
  final accountCount = (existing['accountCount'] as num?)?.toInt() ?? 0;
  final connected = existing['hasConnectedAccount'] == true || accountCount > 0;
  final baseUrlController = TextEditingController(text: savedBaseUrl);
  var errorText = '';
  var busy = false;

  Future<void> save(
    StateSetter setState,
    BuildContext dialogContext, {
    required bool connect,
  }) async {
    setState(() {
      errorText = '';
      busy = true;
    });
    try {
      final baseUrl = baseUrlController.text.trim();
      if (baseUrl.isEmpty) {
        setState(() {
          errorText = 'NeoArchive backend URL is required.';
          busy = false;
        });
        return;
      }
      await controller.saveOfficialIntegrationConfig(
        'neoarchive',
        config: <String, dynamic>{'baseUrl': baseUrl},
      );
      if (connect) {
        await controller.connectOfficialIntegration(
          'neoarchive',
          appId: 'archive',
        );
        if ((controller.errorMessage ?? '').trim().isNotEmpty) {
          setState(() {
            errorText = controller.errorMessage!;
            busy = false;
          });
          return;
        }
      }
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    } catch (_) {
      setState(() {
        errorText =
            controller.errorMessage ?? 'Could not save NeoArchive setup.';
        busy = false;
      });
    }
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('NeoArchive Setup'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Add the NeoArchive backend URL once. NeoAgent will open NeoArchive OAuth so the user can sign in and approve archive access without API keys.',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 16),
              const _IntegrationSetupStatusItem(
                label: 'Connection Method',
                status: 'OAuth companion flow',
                isConnected: true,
              ),
              const SizedBox(height: 12),
              _IntegrationSetupStatusItem(
                label: 'Connected NeoArchive User',
                status: connected
                    ? '$accountCount ${accountCount == 1 ? 'connected user' : 'connected users'}'
                    : 'Not connected',
                isConnected: connected,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'NeoArchive Backend URL',
                  hintText: 'https://archive.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the public base URL of the NeoArchive server. Local self-hosted URLs are supported when NeoAgent can reach them.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              if (errorText.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(errorText, style: TextStyle(color: _danger, fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (savedBaseUrl.isNotEmpty)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirm =
                          await showDialog<bool>(
                            context: dialogContext,
                            builder: (context) => AlertDialog(
                              title: const Text('Disconnect NeoArchive?'),
                              content: const Text(
                                'This removes the NeoArchive backend URL and all connected NeoArchive accounts for this agent.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirm) return;
                      setState(() {
                        busy = true;
                        errorText = '';
                      });
                      try {
                        await controller.clearOfficialIntegrationConfig(
                          'neoarchive',
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (_) {
                        setState(() {
                          errorText =
                              controller.errorMessage ??
                              'Could not disconnect NeoArchive.';
                          busy = false;
                        });
                      }
                    },
              child: const Text('Disconnect'),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (!connected)
            TextButton(
              onPressed: busy
                  ? null
                  : () => save(setState, dialogContext, connect: false),
              child: const Text('Save Only'),
            ),
          FilledButton(
            onPressed: busy
                ? null
                : () => save(setState, dialogContext, connect: !connected),
            child: Text(
              busy
                  ? 'Working...'
                  : connected
                  ? 'Update Setup'
                  : 'Save & Connect',
            ),
          ),
        ],
      ),
    ),
  );
  baseUrlController.dispose();
}

Future<void> _showHomeAssistantSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig('home_assistant');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }

  final savedBaseUrl = existing['baseUrl']?.toString() ?? '';
  final hasToken = existing['hasToken'] == true;
  final accountCount = (existing['accountCount'] as num?)?.toInt() ?? 0;
  final hasConnectedAccount =
      existing['hasConnectedAccount'] == true || accountCount > 0;
  var formError = '';
  var saving = false;

  final baseUrlController = TextEditingController(text: savedBaseUrl);
  final tokenController = TextEditingController();

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Home Assistant Setup'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Connect a public HTTPS Home Assistant endpoint with a Long-Lived Access Token. Local, loopback, and private network addresses are blocked by the server.',
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _IntegrationSetupStatusItem(
                    label: 'Endpoint',
                    status: savedBaseUrl.trim().isNotEmpty
                        ? 'Configured'
                        : 'Not configured',
                    isConnected: savedBaseUrl.trim().isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  _IntegrationSetupStatusItem(
                    label: 'Connected Instance',
                    status: hasConnectedAccount
                        ? '$accountCount ${accountCount == 1 ? 'instance' : 'instances'} connected'
                        : 'Not connected',
                    isConnected: hasConnectedAccount,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Home Assistant URL',
                      hintText: 'https://your-instance.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenController,
                    onChanged: (_) => setState(() {}),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: hasToken
                          ? 'Paste replacement Long-Lived Access Token'
                          : 'Long-Lived Access Token',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (hasToken) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Leave the token empty to keep the currently stored token.',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                  if (formError.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        formError,
                        style: TextStyle(color: _danger, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              if (savedBaseUrl.trim().isNotEmpty || hasToken)
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final shouldClear =
                              await showDialog<bool>(
                                context: dialogContext,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text(
                                      'Disconnect Home Assistant?',
                                    ),
                                    content: const Text(
                                      'This removes the Home Assistant setup and connected instance for this agent.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Disconnect'),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;
                          if (!shouldClear) {
                            return;
                          }
                          setState(() {
                            formError = '';
                            saving = true;
                          });
                          try {
                            await controller.clearOfficialIntegrationConfig(
                              'home_assistant',
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            setState(() {
                              formError =
                                  controller.errorMessage ??
                                  'Could not disconnect Home Assistant.';
                              saving = false;
                            });
                          }
                        },
                  child: const Text('Disconnect'),
                ),
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() {
                          formError = '';
                          saving = true;
                        });
                        try {
                          final baseUrl = baseUrlController.text.trim();
                          final token = tokenController.text.trim();
                          if (baseUrl.isEmpty) {
                            setState(() {
                              formError = 'Home Assistant URL is required.';
                              saving = false;
                            });
                            return;
                          }
                          if (token.isEmpty && !hasToken) {
                            setState(() {
                              formError =
                                  'Home Assistant Long-Lived Access Token is required.';
                              saving = false;
                            });
                            return;
                          }
                          await controller.saveOfficialIntegrationConfig(
                            'home_assistant',
                            config: <String, dynamic>{
                              'baseUrl': baseUrl,
                              if (token.isNotEmpty) 'token': token,
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          setState(() {
                            formError =
                                controller.errorMessage ??
                                'Could not save Home Assistant setup.';
                            saving = false;
                          });
                        }
                      },
                child: Text(
                  saving
                      ? 'Saving...'
                      : hasConnectedAccount
                      ? 'Update Instance'
                      : 'Connect Instance',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  baseUrlController.dispose();
  tokenController.dispose();
}

Future<void> _showTrelloSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig('trello');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage ?? error.toString())),
      );
    }
    return;
  }

  final apiKeyConfigured = existing['apiKeyConfigured'] == true;
  final savedApiKey = existing['apiKey']?.toString() ?? '';
  final apiKeyManagedByServer = apiKeyConfigured && savedApiKey.trim().isEmpty;
  final authorizeUrl = existing['authorizeUrl']?.toString() ?? '';
  final accountCount = (existing['accountCount'] as num?)?.toInt() ?? 0;
  final hasConnectedAccount =
      existing['hasConnectedAccount'] == true || accountCount > 0;
  var formError = '';
  var connecting = false;

  final apiKeyController = TextEditingController(text: savedApiKey);
  final tokenInputController = TextEditingController();

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Trello Setup'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Save a Trello API key for this agent, then connect one Trello account securely. The account token is stored on the server and used only for this agent.',
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _IntegrationSetupStatusItem(
                    label: 'API Key',
                    status: apiKeyConfigured ? 'Configured' : 'Not configured',
                    isConnected: apiKeyConfigured,
                  ),
                  const SizedBox(height: 12),
                  _IntegrationSetupStatusItem(
                    label: 'Connected Account',
                    status: hasConnectedAccount
                        ? '$accountCount ${accountCount == 1 ? 'connected account' : 'connected accounts'}'
                        : 'Not connected',
                    isConnected: hasConnectedAccount,
                  ),
                  if (apiKeyManagedByServer) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'This agent is using a server-managed Trello API key. You only need to authorize an account token below.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKeyController,
                      onChanged: (_) => setState(() {}),
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Trello API Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (apiKeyConfigured ||
                      apiKeyController.text.trim().isNotEmpty ||
                      apiKeyManagedByServer) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: tokenInputController,
                      onChanged: (_) => setState(() {}),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: hasConnectedAccount
                            ? 'Paste a replacement token'
                            : 'Paste your account token',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (formError.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        formError,
                        style: TextStyle(color: _danger, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              if (apiKeyConfigured || savedApiKey.trim().isNotEmpty)
                TextButton(
                  onPressed: connecting
                      ? null
                      : () async {
                          final shouldClear =
                              await showDialog<bool>(
                                context: dialogContext,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Disconnect Trello?'),
                                    content: const Text(
                                      'This removes the Trello setup and connected accounts for this agent.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Disconnect'),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;
                          if (!shouldClear) {
                            return;
                          }
                          setState(() {
                            formError = '';
                            connecting = true;
                          });
                          try {
                            await controller.clearOfficialIntegrationConfig(
                              'trello',
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            setState(() {
                              formError =
                                  controller.errorMessage ??
                                  'Could not disconnect Trello.';
                              connecting = false;
                            });
                          }
                        },
                  child: const Text('Disconnect'),
                ),
              TextButton(
                onPressed: connecting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              if (authorizeUrl.isNotEmpty ||
                  apiKeyManagedByServer ||
                  apiKeyController.text.trim().isNotEmpty)
                FilledButton.icon(
                  onPressed: connecting
                      ? null
                      : () async {
                          setState(() {
                            formError = '';
                            connecting = true;
                          });
                          try {
                            final effectiveApiKey = apiKeyManagedByServer
                                ? ''
                                : apiKeyController.text.trim();
                            if (!apiKeyManagedByServer &&
                                effectiveApiKey.isEmpty) {
                              setState(() {
                                formError = 'Trello API Key is required.';
                                connecting = false;
                              });
                              return;
                            }
                            final url = authorizeUrl.isNotEmpty
                                ? authorizeUrl
                                : 'https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=${Uri.encodeComponent(effectiveApiKey)}';
                            final result = await controller._oauthLauncher
                                .openExternal(url: url, label: 'Trello');
                            if (!result.launched) {
                              setState(() {
                                formError =
                                    result.error ??
                                    'Could not open Trello in your browser.';
                                connecting = false;
                              });
                            } else {
                              setState(() {
                                connecting = false;
                              });
                            }
                          } catch (error) {
                            setState(() {
                              formError = error.toString();
                              connecting = false;
                            });
                          }
                        },
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: Text(connecting ? 'Opening...' : 'Open Trello'),
                ),
              FilledButton(
                onPressed: connecting
                    ? null
                    : () async {
                        setState(() {
                          formError = '';
                          connecting = true;
                        });
                        try {
                          final apiKey = apiKeyController.text.trim();
                          final token = tokenInputController.text.trim();
                          if (!apiKeyManagedByServer && apiKey.isEmpty) {
                            setState(() {
                              formError = 'Trello API Key is required.';
                              connecting = false;
                            });
                            return;
                          }
                          if (token.isEmpty &&
                              apiKeyConfigured &&
                              !apiKeyManagedByServer) {
                            await controller.saveOfficialIntegrationConfig(
                              'trello',
                              config: <String, dynamic>{'apiKey': apiKey},
                            );
                          } else if (token.isEmpty && !apiKeyManagedByServer) {
                            await controller.saveOfficialIntegrationConfig(
                              'trello',
                              config: <String, dynamic>{'apiKey': apiKey},
                            );
                          } else {
                            await controller.saveOfficialIntegrationConfig(
                              'trello',
                              config: <String, dynamic>{
                                if (!apiKeyManagedByServer) 'apiKey': apiKey,
                                'token': token,
                              },
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          setState(() {
                            formError =
                                controller.errorMessage ??
                                'Could not save Trello setup.';
                            connecting = false;
                          });
                        }
                      },
                child: Text(
                  connecting
                      ? 'Saving...'
                      : tokenInputController.text.trim().isNotEmpty
                      ? hasConnectedAccount
                            ? 'Replace Account'
                            : 'Connect Account'
                      : 'Save Setup',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  apiKeyController.dispose();
  tokenInputController.dispose();
}

class _IntegrationSetupStatusItem extends StatelessWidget {
  const _IntegrationSetupStatusItem({
    required this.label,
    required this.status,
    required this.isConnected,
  });

  final String label;
  final String status;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? _success.withValues(alpha: 0.3) : _border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isConnected ? Icons.check_circle_outlined : Icons.circle_outlined,
            size: 18,
            color: isConnected ? _success : _textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isConnected ? _success : _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialIntegrationAppCard extends StatelessWidget {
  const _OfficialIntegrationAppCard({
    required this.controller,
    required this.provider,
    required this.app,
  });

  final NeoAgentController controller;
  final OfficialIntegrationItem provider;
  final OfficialIntegrationAppItem app;

  @override
  Widget build(BuildContext context) {
    final connectBusy = controller.isOfficialIntegrationBusy(
      '${provider.id}:${app.id}:connect',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                app.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusPill(
                              label: app.statusLabel,
                              color: app.isConnected
                                  ? _success
                                  : app.hasExpiredAccounts
                                  ? _warning
                                  : _textSecondary,
                            ),
                          ],
                        ),
                        if ((app.description ?? '')
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            app.description!,
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaPill(
                              label: '${app.accounts.length} accounts',
                              icon: Icons.account_circle_outlined,
                            ),
                            _MetaPill(
                              label: '${app.availableToolCount} tools',
                              icon: Icons.build_circle_outlined,
                            ),
                            _MetaPill(
                              label: app.memoryCoverage.supported
                                  ? 'Memory ${app.memoryCoverage.statusLabel}'
                                  : 'No memory sync',
                              icon: Icons.psychology_alt_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildIntegrationActionButton(context, connectBusy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (app.accounts.isEmpty)
            Text(
              'No accounts connected yet.',
              style: TextStyle(color: _textSecondary),
            )
          else
            Column(
              children: app.accounts.map((account) {
                final disconnectBusy = controller.isOfficialIntegrationBusy(
                  '${provider.id}:${account.id}:disconnect',
                );
                final accessBusy = controller.isOfficialIntegrationBusy(
                  '${provider.id}:${account.id}:access_mode',
                );
                final testBusy = controller.isOfficialIntegrationBusy(
                  '${provider.id}:${account.id}:test',
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: account.connected ? _accentMuted : _border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account.accountEmail ?? 'Unknown account',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connection #${account.id}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Access: ${account.accessModeLabel}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (account.memoryCoverage.supported) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Memory: ${account.memoryCoverage.statusLabel}',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          PopupMenuButton<String>(
                            enabled: !accessBusy,
                            tooltip: 'Access mode',
                            onSelected: (value) {
                              if (value == account.accessMode) return;
                              controller.setOfficialIntegrationAccessMode(
                                provider.id,
                                connectionId: account.id,
                                accessMode: value,
                              );
                            },
                            itemBuilder: (context) =>
                                const <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'read_write',
                                    child: Text('Read / Write'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'read_only',
                                    child: Text('Read Only'),
                                  ),
                                ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.lock_open_rounded,
                                    size: 16,
                                    color: _textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    accessBusy
                                        ? 'Saving...'
                                        : account.accessModeLabel,
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: account.statusLabel,
                            color: account.connected
                                ? _success
                                : account.isExpired
                                ? _warning
                                : _textSecondary,
                          ),
                          if (account.supportsConnectionTest)
                            OutlinedButton.icon(
                              onPressed: testBusy
                                  ? null
                                  : () async {
                                      try {
                                        final result = await controller
                                            .testOfficialIntegration(
                                              provider.id,
                                              connectionId: account.id,
                                            );
                                        if (!context.mounted) return;
                                        final message =
                                            result['message']?.toString() ??
                                            '${provider.label} is connected and responding.';
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              controller.errorMessage ??
                                                  'The connection test failed.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.network_check_rounded),
                              label: Text(
                                testBusy ? 'Testing...' : 'Test Connection',
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: disconnectBusy
                                ? null
                                : () =>
                                      controller.disconnectOfficialIntegration(
                                        provider.id,
                                        connectionId: account.id,
                                      ),
                            icon: Icon(Icons.link_off_rounded),
                            label: Text(
                              disconnectBusy ? 'Working...' : 'Disconnect',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildIntegrationActionButton(BuildContext context, bool connectBusy) {
    if (provider.connectionMethod == 'user_config') {
      return FilledButton.icon(
        onPressed: () => _openOfficialIntegrationSetupDialog(
          context,
          controller,
          provider.id,
        ),
        icon: const Icon(Icons.settings_rounded),
        label: Text(
          provider.env.configured ? 'Manage Setup' : 'Complete Setup',
        ),
      );
    }

    if (!provider.env.configured) {
      return provider.env.setupMode == 'user'
          ? FilledButton.icon(
              onPressed: () => _openOfficialIntegrationSetupDialog(
                context,
                controller,
                provider.id,
              ),
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Configure'),
            )
          : OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.settings_suggest_outlined),
              label: const Text('Admin Setup Required'),
            );
    }

    return FilledButton.icon(
      onPressed: connectBusy
          ? null
          : () => controller.connectOfficialIntegration(
              provider.id,
              appId: app.id,
            ),
      icon: const Icon(Icons.link_rounded),
      label: Text(
        connectBusy
            ? 'Connecting...'
            : provider.supportsMultipleAccounts && app.isConnected
            ? 'Add Account'
            : 'Connect Account',
      ),
    );
  }
}

class _OfficialIntegrationIcon extends StatelessWidget {
  const _OfficialIntegrationIcon({required this.item});

  final OfficialIntegrationItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.icon) {
      'neoarchive' => const Color(0xFFE3B655),
      'neorecall' => const Color(0xFFD98AA6),
      'google' => const Color(0xFF4285F4),
      'home_assistant' => const Color(0xFF41BDF5),
      'password' => const Color(0xFF175DDC),
      'trello' => const Color(0xFF0C66E4),
      _ => _accent,
    };
    final label = switch (item.icon) {
      'neoarchive' => 'A',
      'neorecall' => 'R',
      'google' => 'G',
      'home_assistant' => 'H',
      'password' => 'B',
      'trello' => 'T',
      _ => item.label.isNotEmpty ? item.label[0] : '?',
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

int _compareOfficialIntegrationItems(
  OfficialIntegrationItem a,
  OfficialIntegrationItem b,
) {
  final rankDelta = _officialIntegrationRank(a) - _officialIntegrationRank(b);
  if (rankDelta != 0) {
    return rankDelta;
  }
  return a.label.toLowerCase().compareTo(b.label.toLowerCase());
}

int _officialIntegrationRank(OfficialIntegrationItem item) {
  return switch (item.id) {
    'neoarchive' => 1,
    'neorecall' => 2,
    'google_workspace' => 3,
    _ => 10,
  };
}

class _IntegrationSectionTitle extends StatelessWidget {
  const _IntegrationSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
