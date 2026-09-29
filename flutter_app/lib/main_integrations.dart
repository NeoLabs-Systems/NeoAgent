part of 'main.dart';

void _showControllerError(
  BuildContext context,
  NeoAgentController controller,
  Object error,
) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        controller.errorMessage ?? controller.friendlyErrorMessage(error),
      ),
    ),
  );
}

/// Everything about one official integration — status, guidance, and the
/// per-app connect/account controls — shown from the Tools page.
class IntegrationDetailView extends StatelessWidget {
  const IntegrationDetailView({
    super.key,
    required this.controller,
    required this.providerId,
  });

  final NeoAgentController controller;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.officialIntegrations
            .where((provider) => provider.id == providerId)
            .firstOrNull;
        if (item == null) {
          return Text(
            appStrings.thisIntegrationIsNoLongerAvailable,
            style: TextStyle(color: _textSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.description,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
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
                _MetaPill(
                  label: appStrings.arg1Accounts(item.connection.accountCount),
                  icon: Icons.alternate_email_rounded,
                ),
                _MetaPill(
                  label: appStrings.arg1AppsActive(item.connection.appCount),
                  icon: Icons.apps_rounded,
                ),
                _MetaPill(
                  label: appStrings.arg1Tools(item.availableToolCount),
                  icon: Icons.build_outlined,
                ),
                _MetaPill(
                  label: item.memoryCoverage.supported
                      ? 'Memory ${item.memoryCoverage.statusLabel}'
                      : appStrings.noMemorySync,
                  icon: Icons.psychology_alt_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _integrationGuidance(item),
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
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
        );
      },
    );
  }
}

String _integrationGuidance(OfficialIntegrationItem item) {
  if (!item.env.configured) {
    return item.env.summary;
  }
  if (item.hasExpiredAccounts) {
    return item.id == 'google_workspace'
        ? appStrings.oneOrMoreAccountsExpiredReconnectTo
        : appStrings.oneOrMoreAccountsExpiredReconnect;
  }
  if (!item.supportsMultipleAccounts && item.isConnected) {
    return appStrings.thisIntegrationCurrentlySupportsOneConnected;
  }
  if (item.isConnected) {
    return appStrings.connectAsManyAccountsAsYou;
  }
  final prompt = (item.connectPrompt ?? '').trim();
  return prompt.isNotEmpty
      ? prompt
      : appStrings.connectAppAccountsIndividuallySoThe;
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
    case 'neorecall':
      _showOfficialIntegrationUrlSetupDialog(
        context,
        controller,
        config: _OfficialIntegrationUrlSetupConfig(
          providerId: 'neorecall',
          appId: 'recall',
          title: appStrings.neorecallSetup,
          description:
              appStrings.connectYourSelfHostedNeorecallServer,
          extraDescription:
              appStrings.useANeorecallUrlTheNeoagent,
          connectionMethodLabel: appStrings.oauthWithPkce,
          accountLabel: appStrings.connectedNeorecallUser,
          urlLabel: appStrings.neorecallBackendUrl,
          urlHint: 'https://recall.example.com',
          urlHelperText:
              appStrings.localAndPrivateNetworkUrlsAre,
          urlRequiredMessage: appStrings.neorecallBackendUrlIsRequired,
          saveErrorFallback: appStrings.couldNotSaveNeorecallSetup,
          disconnectTitle: appStrings.disconnectNeorecall,
          disconnectBody:
              appStrings.thisRemovesTheNeorecallBackendUrl,
          disconnectErrorFallback: appStrings.couldNotDisconnectNeorecall,
          supportsMultipleAccounts: true,
        ),
      );
      return;
    case 'nextcloud':
      _showOfficialIntegrationUrlSetupDialog(
        context,
        controller,
        config: _OfficialIntegrationUrlSetupConfig(
          providerId: 'nextcloud',
          appId: 'files',
          title: appStrings.nextcloudSetup,
          description:
              appStrings.connectYourNextcloudInstanceIncludingSelf,
          extraDescription:
              appStrings.useANextcloudUrlTheNeoagent,
          connectionMethodLabel: appStrings.nextcloudLoginFlow,
          accountLabel: appStrings.connectedNextcloudUser,
          urlLabel: appStrings.nextcloudUrl,
          urlHint: 'https://cloud.example.com',
          urlHelperText:
              appStrings.cloudAndSelfHostedInstancesAre,
          urlRequiredMessage: appStrings.nextcloudUrlIsRequired,
          saveErrorFallback: appStrings.couldNotSaveNextcloudSetup,
          disconnectTitle: appStrings.disconnectNextcloud,
          disconnectBody:
              appStrings.thisRemovesTheNextcloudUrlAnd,
          disconnectErrorFallback: appStrings.couldNotDisconnectNextcloud,
          supportsMultipleAccounts: true,
        ),
      );
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
      _showControllerError(context, controller, error);
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
                field['name']?.toString() ?? appStrings.customField,
              ),
            )
            .toList();
        final secretOptions = <(String, String)>[
          ('login.password', appStrings.loginPassword),
          ...customFields,
        ];
        if (!secretOptions.any((entry) => entry.$1 == secretField)) {
          secretField = secretOptions.first.$1;
        }
        return AlertDialog(
          title: Text(appStrings.addCredentialBinding),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: itemId,
                    decoration: InputDecoration(
                      labelText: appStrings.bitwardenItem,
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
                    decoration: InputDecoration(
                      labelText: appStrings.agentVisibleName,
                      hintText: appStrings.workAccount,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: usageType,
                    decoration: InputDecoration(
                      labelText: appStrings.useFor,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'browser',
                        child: Text(appStrings.browserLogin),
                      ),
                      DropdownMenuItem(
                        value: 'http',
                        child: Text(appStrings.apiRequest),
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
                          : appStrings.apiHttpsOrigin,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (usageType == 'http') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pathController,
                      decoration: InputDecoration(
                        labelText: appStrings.allowedPathPrefix,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: authType,
                      decoration: InputDecoration(
                        labelText: appStrings.authentication,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'bearer',
                          child: Text(appStrings.bearerToken),
                        ),
                        DropdownMenuItem(
                          value: 'basic',
                          child: Text(appStrings.basicAuthentication),
                        ),
                        DropdownMenuItem(
                          value: 'header',
                          child: Text(appStrings.customHeader),
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
                      decoration: InputDecoration(
                        labelText: appStrings.secretField,
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
                        decoration: InputDecoration(
                          labelText: appStrings.headerName,
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
              child: Text(appStrings.cancel),
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
                              appStrings.couldNotCreateBinding;
                          saving = false;
                        });
                      }
                    },
              child: Text(saving ? 'Adding...' : appStrings.addBinding),
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
      _showControllerError(context, controller, error);
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
        title: Text(appStrings.bitwardenCredentialBroker),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appStrings.signInWithTheSameEmail,
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serverController,
                  decoration: InputDecoration(
                    labelText: appStrings.bitwardenServer,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: appStrings.accountEmail,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  unlocked
                      ? config['persistent'] == true
                            ? appStrings.vaultConnectedAndAvailableAfterRestart
                            : appStrings.vaultConnectedForThisSession
                      : appStrings.vaultLocked,
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
                        decoration: InputDecoration(
                          labelText: appStrings.masterPassword,
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
                                      appStrings.vaultOperationFailed,
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
                    decoration: InputDecoration(
                      labelText: appStrings.twoStepLoginOnlyIfEnabled,
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(appStrings.notNeeded),
                      ),
                      DropdownMenuItem<String>(
                        value: '0',
                        child: Text(appStrings.authenticatorApp),
                      ),
                      DropdownMenuItem<String>(
                        value: '1',
                        child: Text(appStrings.emailCode),
                      ),
                      DropdownMenuItem<String>(
                        value: '3',
                        child: Text(appStrings.yubikeyOtp),
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
                      decoration: InputDecoration(
                        labelText: appStrings.currentTwoStepLoginCode,
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
                    title: Text(appStrings.keepTheVaultAvailable),
                    subtitle: Text(
                      appStrings.storesOnlyTheBitwardenSessionKey,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appStrings.credentialBindings,
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
                      icon: Icon(Icons.add_rounded),
                      label: Text(appStrings.add),
                    ),
                  ],
                ),
                if (bindings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      appStrings.noBindingsYet,
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
                        tooltip: appStrings.deleteBinding,
                        icon: Icon(Icons.delete_outline_rounded),
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
                              appStrings.couldNotDisconnectBitwarden;
                          busy = false;
                        });
                      }
                    },
              child: Text(appStrings.disconnect),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: Text(appStrings.close),
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
                            appStrings.couldNotSaveBitwardenSetup,
                      );
                    } finally {
                      setState(() => busy = false);
                    }
                  },
            child: Text(busy ? appStrings.saving : appStrings.saveAccount),
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

class _OfficialIntegrationUrlSetupConfig {
  const _OfficialIntegrationUrlSetupConfig({
    required this.providerId,
    required this.appId,
    required this.title,
    required this.description,
    this.extraDescription,
    required this.connectionMethodLabel,
    required this.accountLabel,
    required this.urlLabel,
    required this.urlHint,
    required this.urlHelperText,
    required this.urlRequiredMessage,
    required this.saveErrorFallback,
    required this.disconnectTitle,
    required this.disconnectBody,
    required this.disconnectErrorFallback,
    this.supportsMultipleAccounts = false,
  });

  final String providerId;
  final String appId;
  final String title;
  final String description;
  final String? extraDescription;
  final String connectionMethodLabel;
  final String accountLabel;
  final String urlLabel;
  final String urlHint;
  final String urlHelperText;
  final String urlRequiredMessage;
  final String saveErrorFallback;
  final String disconnectTitle;
  final String disconnectBody;
  final String disconnectErrorFallback;
  final bool supportsMultipleAccounts;
}

Future<void> _showOfficialIntegrationUrlSetupDialog(
  BuildContext context,
  NeoAgentController controller, {
  required _OfficialIntegrationUrlSetupConfig config,
}) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig(config.providerId);
  } catch (error) {
    if (context.mounted) {
      _showControllerError(context, controller, error);
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
          errorText = config.urlRequiredMessage;
          busy = false;
        });
        return;
      }
      await controller.saveOfficialIntegrationConfig(
        config.providerId,
        config: <String, dynamic>{'baseUrl': baseUrl},
      );
      if (connect) {
        await controller.connectOfficialIntegration(
          config.providerId,
          appId: config.appId,
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
        errorText = controller.errorMessage ?? config.saveErrorFallback;
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
        title: Text(config.title),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(config.description, style: TextStyle(color: _textSecondary)),
              if (config.extraDescription != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  config.extraDescription!,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              _IntegrationSetupStatusItem(
                label: appStrings.connectionMethod,
                status: config.connectionMethodLabel,
                isConnected: true,
              ),
              const SizedBox(height: 12),
              _IntegrationSetupStatusItem(
                label: config.accountLabel,
                status: connected
                    ? '$accountCount ${accountCount == 1 ? 'connected user' : 'connected users'}'
                    : appStrings.notConnected,
                isConnected: connected,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: config.urlLabel,
                  hintText: config.urlHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                config.urlHelperText,
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
                              title: Text(config.disconnectTitle),
                              content: Text(config.disconnectBody),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(appStrings.cancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(appStrings.disconnect),
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
                          config.providerId,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (_) {
                        setState(() {
                          errorText =
                              controller.errorMessage ??
                              config.disconnectErrorFallback;
                          busy = false;
                        });
                      }
                    },
              child: Text(appStrings.disconnect),
            ),
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: Text(appStrings.close),
          ),
          if (config.supportsMultipleAccounts || !connected)
            TextButton(
              onPressed: busy
                  ? null
                  : () => save(setState, dialogContext, connect: false),
              child: Text(appStrings.saveOnly),
            ),
          FilledButton(
            onPressed: busy
                ? null
                : () => save(
                    setState,
                    dialogContext,
                    connect: config.supportsMultipleAccounts || !connected,
                  ),
            child: Text(
              busy
                  ? 'Working...'
                  : connected
                  ? (config.supportsMultipleAccounts
                        ? appStrings.connectAnotherAccount
                        : appStrings.updateSetup)
                  : appStrings.saveConnect,
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
      _showControllerError(context, controller, error);
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
            title: Text(appStrings.homeAssistantSetup),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appStrings.connectAPublicHttpsHomeAssistant,
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _IntegrationSetupStatusItem(
                    label: appStrings.endpoint,
                    status: savedBaseUrl.trim().isNotEmpty
                        ? 'Configured'
                        : appStrings.notConfigured,
                    isConnected: savedBaseUrl.trim().isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  _IntegrationSetupStatusItem(
                    label: appStrings.connectedInstance,
                    status: hasConnectedAccount
                        ? '$accountCount ${accountCount == 1 ? 'instance' : 'instances'} connected'
                        : appStrings.notConnected,
                    isConnected: hasConnectedAccount,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: appStrings.homeAssistantUrl,
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
                          ? appStrings.pasteReplacementLongLivedAccessToken
                          : appStrings.longLivedAccessToken,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (hasToken) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      appStrings.leaveTheTokenEmptyToKeep,
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
                                    title: Text(
                                      appStrings.disconnectHomeAssistant,
                                    ),
                                    content: Text(
                                      appStrings.thisRemovesTheHomeAssistantSetup,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(appStrings.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(appStrings.disconnect),
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
                                  appStrings.couldNotDisconnectHomeAssistant;
                              saving = false;
                            });
                          }
                        },
                  child: Text(appStrings.disconnect),
                ),
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(appStrings.close),
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
                              formError = appStrings.homeAssistantUrlIsRequired;
                              saving = false;
                            });
                            return;
                          }
                          if (token.isEmpty && !hasToken) {
                            setState(() {
                              formError =
                                  appStrings.homeAssistantLongLivedAccessToken;
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
                                appStrings.couldNotSaveHomeAssistantSetup;
                            saving = false;
                          });
                        }
                      },
                child: Text(
                  saving
                      ? appStrings.saving
                      : hasConnectedAccount
                      ? appStrings.updateInstance
                      : appStrings.connectInstance,
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
      _showControllerError(context, controller, error);
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
            title: Text(appStrings.trelloSetup),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appStrings.saveATrelloApiKeyFor,
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _IntegrationSetupStatusItem(
                    label: appStrings.apiKey3,
                    status: apiKeyConfigured ? 'Configured' : appStrings.notConfigured,
                    isConnected: apiKeyConfigured,
                  ),
                  const SizedBox(height: 12),
                  _IntegrationSetupStatusItem(
                    label: appStrings.connectedAccount,
                    status: hasConnectedAccount
                        ? '$accountCount ${accountCount == 1 ? 'connected account' : 'connected accounts'}'
                        : appStrings.notConnected,
                    isConnected: hasConnectedAccount,
                  ),
                  if (apiKeyManagedByServer) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      appStrings.thisAgentIsUsingAServer,
                      style: TextStyle(color: _textSecondary),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKeyController,
                      onChanged: (_) => setState(() {}),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: appStrings.trelloApiKey,
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
                            ? appStrings.pasteAReplacementToken
                            : appStrings.pasteYourAccountToken,
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
                                    title: Text(appStrings.disconnectTrello),
                                    content: Text(
                                      appStrings.thisRemovesTheTrelloSetupAnd,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(appStrings.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text(appStrings.disconnect),
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
                                  appStrings.couldNotDisconnectTrello;
                              connecting = false;
                            });
                          }
                        },
                  child: Text(appStrings.disconnect),
                ),
              TextButton(
                onPressed: connecting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(appStrings.close),
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
                                formError = appStrings.trelloApiKeyIsRequired;
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
                                    appStrings.couldNotOpenTrelloInYour;
                                connecting = false;
                              });
                            } else {
                              setState(() {
                                connecting = false;
                              });
                            }
                          } catch (error) {
                            setState(() {
                              formError = controller.friendlyErrorMessage(
                                error,
                              );
                              connecting = false;
                            });
                          }
                        },
                  icon: Icon(Icons.open_in_browser_rounded),
                  label: Text(connecting ? 'Opening...' : appStrings.openTrello),
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
                              formError = appStrings.trelloApiKeyIsRequired;
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
                                appStrings.couldNotSaveTrelloSetup;
                            connecting = false;
                          });
                        }
                      },
                child: Text(
                  connecting
                      ? appStrings.saving
                      : tokenInputController.text.trim().isNotEmpty
                      ? hasConnectedAccount
                            ? appStrings.replaceAccount
                            : appStrings.connectAccount
                      : appStrings.saveSetup,
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
                              label: appStrings.arg1Accounts(app.accounts.length),
                              icon: Icons.account_circle_outlined,
                            ),
                            _MetaPill(
                              label: appStrings.arg1Tools(app.availableToolCount),
                              icon: Icons.build_circle_outlined,
                            ),
                            _MetaPill(
                              label: app.memoryCoverage.supported
                                  ? 'Memory ${app.memoryCoverage.statusLabel}'
                                  : appStrings.noMemorySync,
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
              appStrings.noAccountsConnectedYet,
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
                        account.accountEmail ?? appStrings.unknownAccount,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appStrings.connectionArg1(account.id),
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appStrings.accessArg1(account.accessModeLabel),
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (account.memoryCoverage.supported) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          appStrings.memoryArg1(account.memoryCoverage.statusLabel),
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
                            tooltip: appStrings.accessMode,
                            onSelected: (value) {
                              if (value == account.accessMode) return;
                              controller.setOfficialIntegrationAccessMode(
                                provider.id,
                                connectionId: account.id,
                                accessMode: value,
                              );
                            },
                            itemBuilder: (context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'read_write',
                                    child: Text(appStrings.readWrite),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'read_only',
                                    child: Text(appStrings.readOnly),
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
                                        ? appStrings.saving
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
                                            appStrings.arg1IsConnectedAndResponding(provider.label);
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
                                                  appStrings.theConnectionTestFailed,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: Icon(Icons.network_check_rounded),
                              label: Text(
                                testBusy ? 'Testing...' : appStrings.testConnection2,
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
        icon: Icon(Icons.settings_rounded),
        label: Text(
          provider.env.configured ? 'Manage Setup' : appStrings.completeSetup,
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
              icon: Icon(Icons.settings_rounded),
              label: Text(appStrings.configure),
            )
          : OutlinedButton.icon(
              onPressed: null,
              icon: Icon(Icons.settings_suggest_outlined),
              label: Text(appStrings.setupRequired),
            );
    }

    return FilledButton.icon(
      onPressed: connectBusy
          ? null
          : () => controller.connectOfficialIntegration(
              provider.id,
              appId: app.id,
            ),
      icon: Icon(Icons.link_rounded),
      label: Text(
        connectBusy
            ? 'Connecting...'
            : provider.supportsMultipleAccounts && app.isConnected
            ? appStrings.addAccount
            : appStrings.connectAccount,
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
      'neorecall' => const Color(0xFFD98AA6),
      'nextcloud' => const Color(0xFF0082C9),
      'google' => const Color(0xFF4285F4),
      'home_assistant' => const Color(0xFF41BDF5),
      'password' => const Color(0xFF175DDC),
      'trello' => const Color(0xFF0C66E4),
      _ => _accent,
    };
    final label = switch (item.icon) {
      'neorecall' => 'R',
      'nextcloud' => 'N',
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
    'neorecall' => 1,
    'nextcloud' => 2,
    'google_workspace' => 3,
    _ => 10,
  };
}
