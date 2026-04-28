part of 'main.dart';

class IntegrationsPanel extends StatelessWidget {
  const IntegrationsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          _PageTitle(
            title: 'Integrations',
            subtitle:
                'Connect and manage official integrations separately from reusable skills.',
          ),
          const SizedBox(height: 12),
          Expanded(child: OfficialIntegrationsTab(controller: controller)),
        ],
      ),
    );
  }
}

class OfficialIntegrationsTab extends StatelessWidget {
  const OfficialIntegrationsTab({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final visibleIntegrations = controller.officialIntegrations
        .where(
          (item) =>
              item.env.configured ||
              item.env.setupMode == 'user' ||
              item.isConnected,
        )
        .toList();

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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      !item.env.configured
                          ? item.env.summary
                          : item.hasExpiredAccounts
                          ? 'One or more accounts expired. Reconnect the affected account to restore tool access.'
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
    case 'home_assistant':
      _showHomeAssistantSetupDialog(context, controller);
      return;
    case 'trello':
      _showTrelloSetupDialog(context, controller);
      return;
  }
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

  final baseUrlController = TextEditingController(
    text: existing['baseUrl']?.toString() ?? '',
  );
  final clientIdController = TextEditingController(
    text: existing['clientId']?.toString() ?? '',
  );
  final clientSecretController = TextEditingController();
  final redirectUriController = TextEditingController(
    text: existing['redirectUri']?.toString() ?? '',
  );
  final hasSavedSetup =
      (existing['baseUrl']?.toString().trim().isNotEmpty ?? false) ||
      (existing['clientId']?.toString().trim().isNotEmpty ?? false) ||
      existing['hasClientSecret'] == true;
  var formError = '';
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Home Assistant Setup'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://ha.example.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: clientIdController,
                    decoration: const InputDecoration(
                      labelText: 'OAuth Client ID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: clientSecretController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'OAuth Client Secret',
                      hintText: existing['hasClientSecret'] == true
                          ? 'Saved secret exists. Enter to replace it.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: redirectUriController,
                    decoration: const InputDecoration(
                      labelText: 'Redirect URI (optional)',
                      hintText: 'Leave blank to use the default callback URL',
                    ),
                  ),
                  if (formError.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(formError, style: TextStyle(color: _danger)),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              if (hasSavedSetup)
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final shouldClear =
                              await showDialog<bool>(
                                context: dialogContext,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Clear Setup?'),
                                    content: const Text(
                                      'This removes your saved Home Assistant base URL and OAuth client credentials for this agent.',
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
                                        child: const Text('Clear Setup'),
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
                                  'Could not clear Home Assistant setup.';
                              saving = false;
                            });
                          }
                        },
                  child: const Text('Clear Setup'),
                ),
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
                          formError = '';
                        });
                        final baseUrl = baseUrlController.text.trim();
                        final clientId = clientIdController.text.trim();
                        final clientSecret = clientSecretController.text.trim();
                        final hasSavedSecret =
                            existing['hasClientSecret'] == true;
                        if (baseUrl.isEmpty || clientId.isEmpty) {
                          setState(() {
                            formError =
                                'Base URL and OAuth Client ID are required.';
                          });
                          return;
                        }
                        if (clientSecret.isEmpty && !hasSavedSecret) {
                          setState(() {
                            formError = 'OAuth Client Secret is required.';
                          });
                          return;
                        }

                        setState(() {
                          saving = true;
                        });
                        try {
                          await controller.saveOfficialIntegrationConfig(
                            'home_assistant',
                            config: <String, dynamic>{
                              'baseUrl': baseUrl,
                              'clientId': clientId,
                              if (clientSecret.isNotEmpty)
                                'clientSecret': clientSecret,
                              'redirectUri': redirectUriController.text.trim(),
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
                child: Text(saving ? 'Saving...' : 'Save Setup'),
              ),
            ],
          );
        },
      );
    },
  );

  baseUrlController.dispose();
  clientIdController.dispose();
  clientSecretController.dispose();
  redirectUriController.dispose();
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
                  _TrelloStatusItem(
                    label: 'API Key',
                    status: apiKeyConfigured ? 'Configured' : 'Not configured',
                    isConnected: apiKeyConfigured,
                  ),
                  const SizedBox(height: 12),
                  _TrelloStatusItem(
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
                        color: _danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _danger.withOpacity(0.3)),
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
                                : 'https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=' +
                                      Uri.encodeComponent(effectiveApiKey);
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

class _TrelloStatusItem extends StatelessWidget {
  const _TrelloStatusItem({
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
          color: isConnected ? _success.withOpacity(0.3) : _border,
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
      'google' => const Color(0xFF4285F4),
      'trello' => const Color(0xFF0C66E4),
      _ => _accent,
    };
    final label = switch (item.icon) {
      'google' => 'G',
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
