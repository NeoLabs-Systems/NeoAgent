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

/// Everything about one official integration, shown from the Tools page:
/// what needs doing (if anything), the connected accounts once each, and for
/// multi-app integrations which apps are on.
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
        final notice = _integrationNotice(item);
        final accounts = _groupIntegrationAccounts(item);
        final primary = _integrationPrimaryAction(context, controller, item);
        // Per-app connect rows only where each app is signed in on its own.
        final perApp =
            item.apps.length > 1 &&
            item.connectionMethod == 'oauth' &&
            item.env.configured;
        final sweepApps = item.apps.where((app) => app.memorySweep).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.description,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            if (notice != null) ...<Widget>[
              const SizedBox(height: 16),
              _IntegrationNotice(text: notice.$1, color: notice.$2),
            ],
            if (!item.env.configured &&
                item.env.alternatives.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _IntegrationAlternatives(
                controller: controller,
                providerIds: item.env.alternatives,
                onOpen: (providerId) => _openOfficialIntegrationSetupDialog(
                  context,
                  controller,
                  providerId,
                ),
              ),
            ],
            if (item.env.configured || accounts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 22),
              _IntegrationSectionLabel(appStrings.accounts),
              if (accounts.isEmpty)
                Text(
                  appStrings.noAccountsConnectedYet,
                  style: TextStyle(color: _textSecondary),
                )
              else
                _IntegrationGroupedList(
                  children: accounts
                      .map(
                        (group) => _IntegrationAccountRow(
                          controller: controller,
                          provider: item,
                          group: group,
                        ),
                      )
                      .toList(),
                ),
            ],
            if (primary != null) ...<Widget>[
              const SizedBox(height: 14),
              primary,
            ],
            if (perApp) ...<Widget>[
              const SizedBox(height: 26),
              _IntegrationSectionLabel(appStrings.toolsApps),
              _IntegrationGroupedList(
                children: item.apps
                    .map(
                      (app) => _IntegrationAppRow(
                        controller: controller,
                        provider: item,
                        app: app,
                      ),
                    )
                    .toList(),
              ),
            ],
            for (final app in sweepApps)
              if (app.isConnected || item.env.configured) ...<Widget>[
                const SizedBox(height: 14),
                _EmailMemoryPanel(
                  controller: controller,
                  provider: item,
                  app: app,
                  connectBusy: controller.isOfficialIntegrationBusy(
                    '${item.id}:${app.id}:connect',
                  ),
                ),
              ],
            if (item.usesOwnOAuthApp && item.env.configured) ...<Widget>[
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () =>
                    _showOAuthAppSetupDialog(context, controller, item.id),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(appStrings.yourOAuthApp),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The one thing worth telling someone before they act, or null when the
/// integration simply works.
(String, Color)? _integrationNotice(OfficialIntegrationItem item) {
  if (!item.env.configured) {
    final summary = item.env.summary.trim();
    return summary.isEmpty ? null : (summary, _warning);
  }
  if (item.connectionMethod == 'device' && !item.isConnected) {
    return (
      PhoneSync.supported
          ? appStrings.phoneSyncGuidance
          : appStrings.phoneSyncElsewhereGuidance,
      _info,
    );
  }
  if (item.hasExpiredAccounts) {
    return (
      item.id == 'google_workspace'
          ? appStrings.oneOrMoreAccountsExpiredReconnectTo
          : appStrings.oneOrMoreAccountsExpiredReconnect,
      _warning,
    );
  }
  final prompt = (item.connectPrompt ?? '').trim();
  if (!item.isConnected && prompt.isNotEmpty) return (prompt, _info);
  return null;
}

/// The integration-wide action: setup for integrations configured by hand or
/// on a phone, and the connect button for a single-app sign-in. Multi-app
/// sign-ins connect from their app rows instead.
Widget? _integrationPrimaryAction(
  BuildContext context,
  NeoAgentController controller,
  OfficialIntegrationItem item,
) {
  switch (item.connectionMethod) {
    case 'device':
      if (!PhoneSync.supported) return null;
      return FilledButton.icon(
        onPressed: () => _showPhoneSyncSetup(context, controller),
        icon: const Icon(Icons.smartphone_rounded),
        label: Text(
          item.isConnected
              ? appStrings.manageOnThisPhone
              : appStrings.setUpOnThisPhone,
        ),
      );
    case 'user_config':
      void open() =>
          _openOfficialIntegrationSetupDialog(context, controller, item.id);
      return item.isConnected
          ? OutlinedButton.icon(
              onPressed: open,
              icon: const Icon(Icons.settings_rounded),
              label: Text(appStrings.manage),
            )
          : FilledButton.icon(
              onPressed: open,
              icon: const Icon(Icons.settings_rounded),
              label: Text(appStrings.connect),
            );
  }
  if (!item.env.configured) {
    if (item.env.setupMode != 'user') return null;
    return FilledButton.icon(
      onPressed: () =>
          _openOfficialIntegrationSetupDialog(context, controller, item.id),
      icon: const Icon(Icons.settings_rounded),
      label: Text(appStrings.configure),
    );
  }
  if (item.apps.length > 1 && !item.signInCoversAllApps) {
    return _addAccountToAppMenu(controller, item);
  }
  if (item.apps.isEmpty) return null;
  // A sign-in that covers every app starts from the first one; the server
  // connects the rest it was granted.
  final app = item.apps.first;
  final linked = item.signInCoversAllApps ? item.isConnected : app.isConnected;
  if (linked && !item.supportsMultipleAccounts) return null;
  final busy = controller.isOfficialIntegrationBusy(
    '${item.id}:${app.id}:connect',
  );
  final button = linked ? OutlinedButton.icon : FilledButton.icon;
  if (item.id == 'tailscale' && busy && controller.canCancelTailscaleSignIn) {
    return _TailscaleSignInActions(controller: controller);
  }
  return button(
    onPressed: busy
        ? null
        : () => controller.connectOfficialIntegration(item.id, appId: app.id),
    icon: const Icon(Icons.add_rounded),
    label: Text(
      busy
          ? 'Connecting...'
          : linked
          ? appStrings.addAccount
          : appStrings.connectAccount,
    ),
  );
}

/// Another account for a multi-app sign-in. Each app connects on its own, so
/// the button asks which app; apps not on yet connect from their rows.
Widget? _addAccountToAppMenu(
  NeoAgentController controller,
  OfficialIntegrationItem item,
) {
  final apps = item.apps.where((app) => app.isConnected).toList();
  if (!item.supportsMultipleAccounts || apps.isEmpty) return null;
  final busy = apps.any(
    (app) =>
        controller.isOfficialIntegrationBusy('${item.id}:${app.id}:connect'),
  );
  return MenuAnchor(
    builder: (context, menu, _) => OutlinedButton.icon(
      onPressed: busy ? null : () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.add_rounded),
      label: Text(busy ? 'Connecting...' : appStrings.addAccount),
    ),
    menuChildren: <Widget>[
      for (final app in apps)
        MenuItemButton(
          onPressed: () =>
              controller.connectOfficialIntegration(item.id, appId: app.id),
          child: Text(app.label),
        ),
    ],
  );
}

/// One person's sign-in to an integration, with the per-app connections it
/// is made of. Multi-app integrations keep one connection per app, so the
/// same account would otherwise show once for every app.
class _IntegrationAccountGroup {
  _IntegrationAccountGroup(this.label);

  final String label;
  final List<(OfficialIntegrationAppItem, OfficialIntegrationAccountItem)>
  links = <(OfficialIntegrationAppItem, OfficialIntegrationAccountItem)>[];

  Iterable<OfficialIntegrationAccountItem> get accounts =>
      links.map((link) => link.$2);

  bool get connected => accounts.any((account) => account.connected);

  List<String> appLabels({required bool connected}) => links
      .where((link) => link.$2.connected == connected)
      .map((link) => link.$1.label)
      .toList();

  List<OfficialIntegrationAppItem> get expiredApps => links
      .where((link) => link.$2.isExpired && !link.$2.connected)
      .map((link) => link.$1)
      .toList();
}

List<_IntegrationAccountGroup> _groupIntegrationAccounts(
  OfficialIntegrationItem item,
) {
  final groups = <String, _IntegrationAccountGroup>{};
  for (final app in item.apps) {
    for (final account in app.accounts) {
      final email = account.accountEmail?.trim() ?? '';
      final key = email.isEmpty
          ? 'connection:${account.id}'
          : email.toLowerCase();
      final group = groups.putIfAbsent(
        key,
        () => _IntegrationAccountGroup(
          email.isEmpty ? appStrings.unknownAccount : email,
        ),
      );
      group.links.add((app, account));
    }
  }
  return groups.values.toList();
}

class _IntegrationSectionLabel extends StatelessWidget {
  const _IntegrationSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Rows in one rounded box with hairline dividers, like a settings list.
class _IntegrationGroupedList extends StatelessWidget {
  const _IntegrationGroupedList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) Divider(height: 1, color: _border),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _IntegrationNotice extends StatelessWidget {
  const _IntegrationNotice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            color == _warning
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _textPrimary, height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationAccountRow extends StatelessWidget {
  const _IntegrationAccountRow({
    required this.controller,
    required this.provider,
    required this.group,
  });

  final NeoAgentController controller;
  final OfficialIntegrationItem provider;
  final _IntegrationAccountGroup group;

  bool _busy(String action) => group.accounts.any(
    (account) => controller.isOfficialIntegrationBusy(
      '${provider.id}:${account.id}:$action',
    ),
  );

  Future<void> _setAccessMode(String mode) async {
    for (final account in group.accounts) {
      if (account.accessMode == mode) continue;
      await controller.setOfficialIntegrationAccessMode(
        provider.id,
        connectionId: account.id,
        accessMode: mode,
      );
    }
  }

  Future<void> _test(BuildContext context) async {
    final account = group.accounts.firstWhere(
      (account) => account.connected && account.supportsConnectionTest,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await controller.testOfficialIntegration(
        provider.id,
        connectionId: account.id,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                appStrings.arg1IsConnectedAndResponding(provider.label),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ?? appStrings.theConnectionTestFailed,
          ),
        ),
      );
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final apps = group.links.map((link) => link.$1.label).toList();
    final confirmed = await _confirmIntegrationAction(
      context,
      title: appStrings.disconnectAccountTitle(group.label),
      body: appStrings.disconnectAccountBody(
        provider.apps.length > 1 ? apps.join(', ') : provider.label,
      ),
      confirmLabel: appStrings.disconnect,
    );
    if (!confirmed) return;
    for (final account in group.accounts.toList()) {
      await controller.disconnectOfficialIntegration(
        provider.id,
        connectionId: account.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiApp = provider.apps.length > 1;
    final expiredApps = group.expiredApps;
    final onApps = group.appLabels(connected: true);
    // What works, then what needs a reconnect, so a partly expired account
    // still shows the apps it keeps.
    final working = multiApp && onApps.isNotEmpty
        ? onApps.join(' · ')
        : group.connected && expiredApps.isEmpty
        ? appStrings.connected
        : expiredApps.isEmpty
        ? group.accounts.first.statusLabel
        : '';
    final warning = expiredApps.isEmpty
        ? ''
        : multiApp
        ? '${appStrings.reconnectNeeded}: ${expiredApps.map((app) => app.label).join(', ')}'
        : appStrings.reconnectNeeded;
    final modes = group.accounts.map((account) => account.accessMode).toSet();
    final accessBusy = _busy('access_mode');
    // Read / write is the default; only a restriction is worth a word.
    final access = accessBusy
        ? appStrings.saving
        : modes.length > 1
        ? appStrings.mixedAccess
        : modes.first == 'read_only'
        ? appStrings.readOnly
        : null;
    final canTest = group.accounts.any(
      (account) => account.connected && account.supportsConnectionTest,
    );
    final initial = group.label.isEmpty ? '?' : group.label[0].toUpperCase();
    final color = expiredApps.isNotEmpty ? _warning : _accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Text(
              initial,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: <String>[
                          working,
                          ?access,
                        ].where((part) => part.isNotEmpty).join(' · '),
                      ),
                      if (warning.isNotEmpty) ...<InlineSpan>[
                        if (working.isNotEmpty || access != null)
                          const TextSpan(text: ' · '),
                        TextSpan(
                          text: warning,
                          style: TextStyle(color: _warning),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: appStrings.moreActions,
            enabled: !accessBusy,
            icon: Icon(Icons.more_horiz_rounded, color: _textSecondary),
            position: PopupMenuPosition.under,
            onSelected: (action) {
              switch (action) {
                case 'services':
                  _showTailscaleServiceAccess(
                    context,
                    controller,
                    group.accounts.first.id,
                  );
                case 'test':
                  _test(context);
                case 'reconnect':
                  controller.connectOfficialIntegration(
                    provider.id,
                    appId: expiredApps.first.id,
                  );
                case 'disconnect':
                  _disconnect(context);
                default:
                  _setAccessMode(action);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              CheckedPopupMenuItem<String>(
                value: 'read_write',
                checked: modes.length == 1 && modes.first == 'read_write',
                child: Text(appStrings.readWrite),
              ),
              CheckedPopupMenuItem<String>(
                value: 'read_only',
                checked: modes.length == 1 && modes.first == 'read_only',
                child: Text(appStrings.readOnly),
              ),
              const PopupMenuDivider(),
              if (provider.id == 'tailscale' &&
                  group.accounts.any((account) => account.connected))
                PopupMenuItem<String>(
                  value: 'services',
                  child: Text(appStrings.tailscaleServiceAccess),
                ),
              if (expiredApps.isNotEmpty &&
                  provider.connectionMethod == 'oauth')
                PopupMenuItem<String>(
                  value: 'reconnect',
                  child: Text(appStrings.reconnect),
                ),
              if (canTest)
                PopupMenuItem<String>(
                  value: 'test',
                  enabled: !_busy('test'),
                  child: Text(appStrings.testConnection2),
                ),
              PopupMenuItem<String>(
                value: 'disconnect',
                enabled: !_busy('disconnect'),
                child: Text(
                  appStrings.disconnect,
                  style: TextStyle(color: _danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One app of a multi-app sign-in: whether it is on, and, where each app
/// signs in on its own, the button that turns it on or reconnects it.
class _IntegrationAppRow extends StatelessWidget {
  const _IntegrationAppRow({
    required this.controller,
    required this.provider,
    required this.app,
  });

  final NeoAgentController controller;
  final OfficialIntegrationItem provider;
  final OfficialIntegrationAppItem app;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isOfficialIntegrationBusy(
      '${provider.id}:${app.id}:connect',
    );
    final expired = !app.isConnected && app.hasExpiredAccounts;
    final description = (app.description ?? '').trim();
    final connect = busy
        ? null
        : () => controller.connectOfficialIntegration(provider.id, appId: app.id);

    final Widget? action;
    if (busy) {
      action = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (app.isConnected || provider.signInCoversAllApps) {
      action = null;
    } else {
      action = FilledButton.tonal(
        onPressed: connect,
        child: Text(expired ? appStrings.reconnect : appStrings.connect),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: <Widget>[
          Icon(
            app.isConnected
                ? Icons.check_circle_rounded
                : expired
                ? Icons.error_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: app.isConnected
                ? _success
                : expired
                ? _warning
                : _textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  app.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textSecondary, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 10), action],
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
    case 'news':
      _showWorldNewsSetupDialog(context, controller);
      return;
    case 'email':
      _showEmailAccountSetupDialog(context, controller);
      return;
    case 'phone':
      if (PhoneSync.supported) _showPhoneSyncSetup(context, controller);
      return;
    default:
      _showOAuthAppSetupDialog(context, controller, providerId);
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
        return _IntegrationDialog(
          icon: 'password',
          title: appStrings.addCredentialBinding,
          error: errorText,
          onClose: saving ? null : () => Navigator.of(dialogContext).pop(),
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
          ],
          actions: <Widget>[
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
              child: _IntegrationBusyLabel(
                busy: saving,
                label: appStrings.addBinding,
              ),
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
  var verificationCodeRequested = false;
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
  final twoStepCodeFocus = FocusNode();
  const defaultBitwardenServer = 'https://vault.bitwarden.com';
  // Most people use the hosted vault; only show the server field when it is
  // already customised or the user asks for it.
  var showServerField =
      serverController.text.trim().isNotEmpty &&
      serverController.text.trim() != defaultBitwardenServer;
  var showMasterPassword = false;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> toggleVault() async {
          setState(() {
            busy = true;
            errorText = '';
          });
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
              await controller.saveOfficialIntegrationConfig(
                'bitwarden',
                config: <String, dynamic>{
                  'serverUrl': serverController.text.trim(),
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
              verificationCodeRequested = false;
            }
          } catch (error) {
            errorText =
                controller.errorMessage ?? appStrings.vaultOperationFailed;
            if (error is BackendException &&
                error.code == 'BITWARDEN_VERIFICATION_CODE_REQUIRED') {
              verificationCodeRequested = true;
              twoStepCodeController.clear();
            }
          } finally {
            setState(() => busy = false);
          }
          if (verificationCodeRequested && !unlocked) {
            twoStepCodeFocus.requestFocus();
          }
        }

        final canConnect =
            !busy &&
            emailController.text.trim().isNotEmpty &&
            masterPasswordController.text.isNotEmpty;
        void submitIfReady() {
          if (canConnect) toggleVault();
        }

        Future<void> saveAccount() async {
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
            config = await controller.getOfficialIntegrationConfig('bitwarden');
          } catch (_) {
            errorText =
                controller.errorMessage ?? appStrings.couldNotSaveBitwardenSetup;
          } finally {
            setState(() => busy = false);
          }
        }

        final vaultStatus = unlocked
            ? config['persistent'] == true
                  ? appStrings.vaultConnectedAndAvailableAfterRestart
                  : appStrings.vaultConnectedForThisSession
            : appStrings.vaultLocked;

        return _IntegrationDialog(
          icon: 'password',
          title: appStrings.bitwardenCredentialBroker,
          subtitle: appStrings.signInWithTheSameEmail,
          width: 600,
          status: <_IntegrationSetupStatusItem>[
            _IntegrationSetupStatusItem(
              label: 'Vault',
              status: vaultStatus,
              isConnected: unlocked,
            ),
          ],
          error: errorText,
          onClose: busy ? null : () => Navigator.of(dialogContext).pop(),
          children: <Widget>[
            _OAuthAppStep(
              number: 1,
              first: true,
              title: appStrings.accountEmail,
              children: <Widget>[
                TextField(
                  controller: emailController,
                  enabled: !busy && !unlocked,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofocus: emailController.text.trim().isEmpty,
                  autofillHints: const <String>[AutofillHints.email],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: appStrings.accountEmail,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (showServerField)
                  TextField(
                    controller: serverController,
                    enabled: !busy && !unlocked,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: appStrings.bitwardenServer,
                      hintText: defaultBitwardenServer,
                      prefixIcon: const Icon(Icons.dns_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy || unlocked
                          ? null
                          : () => setState(() => showServerField = true),
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(appStrings.bitwardenServer),
                    ),
                  ),
              ],
            ),
            _OAuthAppStep(
              number: 2,
              title: unlocked ? 'Vault' : appStrings.masterPassword,
              children: <Widget>[
                if (unlocked)
                  _RowSurface(
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.lock_open_rounded, color: _success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            vaultStatus,
                            style: TextStyle(color: _success),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : toggleVault,
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          label: const Text('Lock'),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  TextField(
                    controller: masterPasswordController,
                    obscureText: !showMasterPassword,
                    enabled: !busy,
                    autofocus: emailController.text.trim().isNotEmpty,
                    autofillHints: const <String>[AutofillHints.password],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => submitIfReady(),
                    decoration: InputDecoration(
                      labelText: appStrings.masterPassword,
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showMasterPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => showMasterPassword = !showMasterPassword,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (verificationCodeRequested ||
                      twoStepMethod.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: twoStepMethod,
                      decoration: InputDecoration(
                        labelText: appStrings.twoStepLoginOnlyIfEnabled,
                        border: const OutlineInputBorder(),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: twoStepCodeController,
                      focusNode: twoStepCodeFocus,
                      enabled: !busy,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => submitIfReady(),
                      decoration: InputDecoration(
                        labelText: appStrings.currentTwoStepLoginCode,
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: persistSession,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => persistSession = value),
                    title: Text(appStrings.keepTheVaultAvailable),
                    subtitle: Text(
                      appStrings.storesOnlyTheBitwardenSessionKey,
                      style: TextStyle(color: _textSecondary, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: canConnect ? toggleVault : null,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: _IntegrationBusyLabel(busy: busy, label: 'Connect'),
                  ),
                ],
              ],
            ),
            _OAuthAppStep(
              number: 3,
              title: appStrings.credentialBindings,
              children: <Widget>[
                if (bindings.isEmpty)
                  _RowSurface(
                    child: Text(
                      appStrings.noBindingsYet,
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                else
                  for (final binding in bindings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RowSurface(
                        child: Row(
                          children: <Widget>[
                            Icon(
                              binding['usageType'] == 'http'
                                  ? Icons.api_rounded
                                  : Icons.language_rounded,
                              size: 20,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    binding['alias']?.toString() ??
                                        'Credential',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    binding['usageType'] == 'http'
                                        ? appStrings.apiRequest
                                        : appStrings.browserLogin,
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: appStrings.deleteBinding,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: _danger,
                              ),
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
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
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
                          bindings = await controller.fetchCredentialBindings();
                          setState(() {});
                        },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(appStrings.addBinding),
                ),
              ],
            ),
          ],
          leading: config['configured'] == true
              ? _IntegrationDangerButton(
                  label: appStrings.disconnect,
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
                )
              : null,
          actions: <Widget>[
            if (!unlocked)
              FilledButton.tonal(
                onPressed: busy ? null : saveAccount,
                child: Text(appStrings.saveAccount),
              ),
          ],
        );
      },
    ),
  );
  serverController.dispose();
  emailController.dispose();
  masterPasswordController.dispose();
  twoStepCodeController.dispose();
  twoStepCodeFocus.dispose();
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
      builder: (dialogContext, setState) => _IntegrationDialog(
        icon: _integrationIconFor(controller, config.providerId),
        title: config.title,
        subtitle: config.description,
        status: <_IntegrationSetupStatusItem>[
          _IntegrationSetupStatusItem(
            label: appStrings.connectionMethod,
            status: config.connectionMethodLabel,
            isConnected: true,
          ),
          _IntegrationSetupStatusItem(
            label: config.accountLabel,
            status: connected
                ? '$accountCount ${accountCount == 1 ? 'connected user' : 'connected users'}'
                : appStrings.notConnected,
            isConnected: connected,
          ),
        ],
        error: errorText,
        onClose: busy ? null : () => Navigator.of(dialogContext).pop(),
        children: <Widget>[
          TextField(
            controller: baseUrlController,
            enabled: !busy,
            autofocus: savedBaseUrl.isEmpty,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: config.urlLabel,
              hintText: config.urlHint,
              prefixIcon: const Icon(Icons.link_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          _IntegrationHint(config.urlHelperText),
          if (config.extraDescription != null)
            _IntegrationHint(
              config.extraDescription!,
              icon: Icons.lightbulb_outline_rounded,
            ),
        ],
        leading: savedBaseUrl.isEmpty
            ? null
            : _IntegrationDangerButton(
                label: appStrings.disconnect,
                onPressed: busy
                    ? null
                    : () async {
                        final confirm = await _confirmIntegrationAction(
                          dialogContext,
                          title: config.disconnectTitle,
                          body: config.disconnectBody,
                          confirmLabel: appStrings.disconnect,
                        );
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
              ),
        actions: <Widget>[
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
            child: _IntegrationBusyLabel(
              busy: busy,
              label: connected
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
          Future<void> disconnect() async {
            final shouldClear = await _confirmIntegrationAction(
              dialogContext,
              title: appStrings.disconnectHomeAssistant,
              body: appStrings.thisRemovesTheHomeAssistantSetup,
              confirmLabel: appStrings.disconnect,
            );
            if (!shouldClear) return;
            setState(() {
              formError = '';
              saving = true;
            });
            try {
              await controller.clearOfficialIntegrationConfig('home_assistant');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ??
                    appStrings.couldNotDisconnectHomeAssistant;
                saving = false;
              });
            }
          }

          Future<void> submit() async {
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
                  formError = appStrings.homeAssistantLongLivedAccessToken;
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
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ??
                    appStrings.couldNotSaveHomeAssistantSetup;
                saving = false;
              });
            }
          }

          return _IntegrationDialog(
            icon: 'home_assistant',
            title: appStrings.homeAssistantSetup,
            subtitle: appStrings.connectAPublicHttpsHomeAssistant,
            status: <_IntegrationSetupStatusItem>[
              _IntegrationSetupStatusItem(
                label: appStrings.endpoint,
                status: savedBaseUrl.trim().isNotEmpty
                    ? 'Configured'
                    : appStrings.notConfigured,
                isConnected: savedBaseUrl.trim().isNotEmpty,
              ),
              _IntegrationSetupStatusItem(
                label: appStrings.connectedInstance,
                status: hasConnectedAccount
                    ? '$accountCount ${accountCount == 1 ? 'instance' : 'instances'} connected'
                    : appStrings.notConnected,
                isConnected: hasConnectedAccount,
              ),
            ],
            error: formError,
            onClose: saving ? null : () => Navigator.of(dialogContext).pop(),
            children: <Widget>[
              TextField(
                controller: baseUrlController,
                enabled: !saving,
                autofocus: savedBaseUrl.isEmpty,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: appStrings.homeAssistantUrl,
                  hintText: 'https://your-instance.example.com',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              _AdminCfgSecretField(
                controller: tokenController,
                label: hasToken
                    ? appStrings.pasteReplacementLongLivedAccessToken
                    : appStrings.longLivedAccessToken,
                stored: hasToken,
              ),
            ],
            leading: savedBaseUrl.trim().isNotEmpty || hasToken
                ? _IntegrationDangerButton(
                    label: appStrings.disconnect,
                    onPressed: saving ? null : disconnect,
                  )
                : null,
            actions: <Widget>[
              FilledButton(
                onPressed: saving ? null : submit,
                child: _IntegrationBusyLabel(
                  busy: saving,
                  label: hasConnectedAccount
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

Future<void> _showWorldNewsSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> existing;
  try {
    existing = await controller.getOfficialIntegrationConfig('news');
  } catch (error) {
    if (context.mounted) {
      _showControllerError(context, controller, error);
    }
    return;
  }

  final hasApiKey = existing['hasApiKey'] == true;
  var formError = '';
  var saving = false;
  final apiKeyController = TextEditingController();

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> disconnect() async {
            final shouldClear = await _confirmIntegrationAction(
              dialogContext,
              title: appStrings.disconnectWorldNews,
              body: appStrings.thisRemovesTheGnewsApiKey,
              confirmLabel: appStrings.disconnect,
            );
            if (!shouldClear) return;
            setState(() {
              formError = '';
              saving = true;
            });
            try {
              await controller.clearOfficialIntegrationConfig('news');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ??
                    appStrings.couldNotDisconnectWorldNews;
                saving = false;
              });
            }
          }

          Future<void> submit() async {
            final apiKey = apiKeyController.text.trim();
            if (apiKey.isEmpty && !hasApiKey) {
              setState(() => formError = appStrings.gnewsApiKeyIsRequired);
              return;
            }
            setState(() {
              formError = '';
              saving = true;
            });
            try {
              await controller.saveOfficialIntegrationConfig(
                'news',
                config: <String, dynamic>{
                  if (apiKey.isNotEmpty) 'apiKey': apiKey,
                },
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ??
                    appStrings.couldNotSaveWorldNewsSetup;
                saving = false;
              });
            }
          }

          return _IntegrationDialog(
            icon: 'news',
            title: appStrings.worldNewsSetup,
            subtitle: appStrings.connectWorldNewsWithGnews,
            status: <_IntegrationSetupStatusItem>[
              _IntegrationSetupStatusItem(
                label: appStrings.gnewsApiKey,
                status: hasApiKey ? 'Configured' : appStrings.notConfigured,
                isConnected: hasApiKey,
              ),
            ],
            error: formError,
            onClose: saving ? null : () => Navigator.of(dialogContext).pop(),
            children: <Widget>[
              _AdminCfgSecretField(
                controller: apiKeyController,
                label: hasApiKey
                    ? appStrings.pasteReplacementGnewsApiKey
                    : appStrings.gnewsApiKey,
                stored: hasApiKey,
              ),
            ],
            leading: hasApiKey
                ? _IntegrationDangerButton(
                    label: appStrings.disconnect,
                    onPressed: saving ? null : disconnect,
                  )
                : null,
            actions: <Widget>[
              FilledButton(
                onPressed: saving ? null : submit,
                child: _IntegrationBusyLabel(
                  busy: saving,
                  label: appStrings.saveConnect,
                ),
              ),
            ],
          );
        },
      );
    },
  );

  apiKeyController.dispose();
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
          Future<void> disconnect() async {
            final shouldClear = await _confirmIntegrationAction(
              dialogContext,
              title: appStrings.disconnectTrello,
              body: appStrings.thisRemovesTheTrelloSetupAnd,
              confirmLabel: appStrings.disconnect,
            );
            if (!shouldClear) return;
            setState(() {
              formError = '';
              connecting = true;
            });
            try {
              await controller.clearOfficialIntegrationConfig('trello');
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ?? appStrings.couldNotDisconnectTrello;
                connecting = false;
              });
            }
          }

          Future<void> openTrello() async {
            setState(() {
              formError = '';
              connecting = true;
            });
            try {
              final effectiveApiKey = apiKeyManagedByServer
                  ? ''
                  : apiKeyController.text.trim();
              if (!apiKeyManagedByServer && effectiveApiKey.isEmpty) {
                setState(() {
                  formError = appStrings.trelloApiKeyIsRequired;
                  connecting = false;
                });
                return;
              }
              final url = authorizeUrl.isNotEmpty
                  ? authorizeUrl
                  : 'https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=${Uri.encodeComponent(effectiveApiKey)}';
              final result = await controller._oauthLauncher.openExternal(
                url: url,
                label: 'Trello',
              );
              setState(() {
                if (!result.launched) {
                  formError =
                      result.error ?? appStrings.couldNotOpenTrelloInYour;
                }
                connecting = false;
              });
            } catch (error) {
              setState(() {
                formError = controller.friendlyErrorMessage(error);
                connecting = false;
              });
            }
          }

          Future<void> submit() async {
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
              await controller.saveOfficialIntegrationConfig(
                'trello',
                config: <String, dynamic>{
                  if (!apiKeyManagedByServer) 'apiKey': apiKey,
                  if (token.isNotEmpty || apiKeyManagedByServer) 'token': token,
                },
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            } catch (_) {
              setState(() {
                formError =
                    controller.errorMessage ?? appStrings.couldNotSaveTrelloSetup;
                connecting = false;
              });
            }
          }

          final keyReady =
              apiKeyConfigured ||
              apiKeyManagedByServer ||
              apiKeyController.text.trim().isNotEmpty;
          final canAuthorize =
              authorizeUrl.isNotEmpty ||
              apiKeyManagedByServer ||
              apiKeyController.text.trim().isNotEmpty;
          var step = 0;
          return _IntegrationDialog(
            icon: 'trello',
            title: appStrings.trelloSetup,
            subtitle: appStrings.saveATrelloApiKeyFor,
            status: <_IntegrationSetupStatusItem>[
              _IntegrationSetupStatusItem(
                label: appStrings.apiKey3,
                status: apiKeyConfigured
                    ? 'Configured'
                    : appStrings.notConfigured,
                isConnected: apiKeyConfigured,
              ),
              _IntegrationSetupStatusItem(
                label: appStrings.connectedAccount,
                status: hasConnectedAccount
                    ? '$accountCount ${accountCount == 1 ? 'connected account' : 'connected accounts'}'
                    : appStrings.notConnected,
                isConnected: hasConnectedAccount,
              ),
            ],
            error: formError,
            onClose: connecting
                ? null
                : () => Navigator.of(dialogContext).pop(),
            children: <Widget>[
              if (apiKeyManagedByServer)
                _IntegrationHint(
                  appStrings.thisAgentIsUsingAServer,
                  icon: Icons.verified_outlined,
                )
              else
                _OAuthAppStep(
                  number: ++step,
                  first: true,
                  title: appStrings.trelloApiKey,
                  children: <Widget>[
                    _AdminCfgSecretField(
                      controller: apiKeyController,
                      label: appStrings.trelloApiKey,
                      stored: apiKeyConfigured,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              if (keyReady) ...<Widget>[
                if (canAuthorize)
                  _OAuthAppStep(
                    number: ++step,
                    title: appStrings.openTrello,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: connecting ? null : openTrello,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(appStrings.openTrello),
                        ),
                      ),
                    ],
                  ),
                _OAuthAppStep(
                  number: ++step,
                  title: hasConnectedAccount
                      ? appStrings.pasteAReplacementToken
                      : appStrings.pasteYourAccountToken,
                  children: <Widget>[
                    _AdminCfgSecretField(
                      controller: tokenInputController,
                      label: hasConnectedAccount
                          ? appStrings.pasteAReplacementToken
                          : appStrings.pasteYourAccountToken,
                      stored: false,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ],
            ],
            leading: apiKeyConfigured || savedApiKey.trim().isNotEmpty
                ? _IntegrationDangerButton(
                    label: appStrings.disconnect,
                    onPressed: connecting ? null : disconnect,
                  )
                : null,
            actions: <Widget>[
              FilledButton(
                onPressed: connecting ? null : submit,
                child: _IntegrationBusyLabel(
                  busy: connecting,
                  label: tokenInputController.text.trim().isNotEmpty
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
    final tone = isConnected ? _success : _textMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: isConnected
            ? _success.withValues(alpha: 0.1)
            : _bgSecondary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isConnected ? _success.withValues(alpha: 0.3) : _border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$label  ',
                    style: TextStyle(color: _textSecondary),
                  ),
                  TextSpan(
                    text: status,
                    style: TextStyle(
                      color: isConnected ? _success : _textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Importing a mailbox's important past mail into memory: whether it runs
/// when an account connects, a manual "import now", and live progress.
class _EmailMemoryPanel extends StatelessWidget {
  const _EmailMemoryPanel({
    required this.controller,
    required this.provider,
    required this.app,
    required this.connectBusy,
  });

  final NeoAgentController controller;
  final OfficialIntegrationItem provider;
  final OfficialIntegrationAppItem app;
  final bool connectBusy;

  @override
  Widget build(BuildContext context) {
    final sweeps = app.accounts
        .map(controller.memorySweepFor)
        .whereType<MemorySweepProgress>()
        .toList();
    final running = sweeps.where((sweep) => sweep.isRunning).toList();
    final failed = sweeps.where((sweep) => sweep.isFailed).toList();
    final completed = sweeps.where((sweep) => sweep.isCompleted).toList();
    final current = running.isEmpty ? null : _combine(running);
    final fraction = current?.fraction;
    final startBusy = controller.isOfficialIntegrationBusy(
      '${provider.id}:${app.id}:sweep',
    );
    final theme = Theme.of(context);

    final String status;
    var statusColor = _textSecondary;
    if (current != null) {
      status = _runningLabel(current);
    } else if (failed.isNotEmpty) {
      status = appStrings.sweepFailed(failed.first.error ?? '');
      statusColor = _danger;
    } else if (completed.isNotEmpty) {
      final imported = completed.fold<int>(0, (sum, sweep) => sum + sweep.imported);
      final learned = completed.fold<int>(0, (sum, sweep) => sum + sweep.learned);
      status = imported > 0
          ? appStrings.sweepLastImport(imported, learned)
          : appStrings.sweepNothingNew;
    } else {
      status = appStrings.importPastEmailsIntoMemoryHint;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 18, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      appStrings.emailMemory,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        status,
                        key: ValueKey<String>(status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (current != null)
                Text(
                  fraction == null ? '' : '${(fraction * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                )
              else if (app.isConnected)
                TextButton.icon(
                  onPressed: startBusy
                      ? null
                      : () async {
                          try {
                            await controller.importPastEmails(provider.id, app.id);
                          } catch (error) {
                            if (context.mounted) {
                              _showControllerError(context, controller, error);
                            }
                          }
                        },
                  icon: Icon(Icons.download_rounded, size: 18),
                  label: Text(appStrings.importNow),
                ),
            ],
          ),
          if (current != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: fraction ?? 0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: fraction == null ? null : value,
                  minHeight: 6,
                  color: _accent,
                  backgroundColor: _border,
                ),
              ),
            ),
          ],
          if (provider.env.configured) ...<Widget>[
            const SizedBox(height: 10),
            Divider(height: 1, color: _borderLight),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    appStrings.importOnConnect,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: controller.isMemorySweepEnabled(provider.id, app.id),
                    onChanged: connectBusy
                        ? null
                        : (value) => controller.setMemorySweepEnabled(
                            provider.id,
                            app.id,
                            value,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Several accounts importing at once read as one import.
  static MemorySweepProgress _combine(List<MemorySweepProgress> sweeps) {
    if (sweeps.length == 1) return sweeps.single;
    const phases = <String>['reading', 'learning'];
    final phase = sweeps
        .map((sweep) => sweep.phase)
        .reduce((a, b) => phases.indexOf(a) <= phases.indexOf(b) ? a : b);
    final inPhase = sweeps.where((sweep) => sweep.phase == phase);
    final unknownTotal = inPhase.any((sweep) => sweep.total == null);
    return MemorySweepProgress(
      state: 'running',
      phase: phase,
      done: inPhase.fold<int>(0, (sum, sweep) => sum + sweep.done),
      total: unknownTotal
          ? null
          : inPhase.fold<int>(0, (sum, sweep) => sum + (sweep.total ?? 0)),
    );
  }

  static String _runningLabel(MemorySweepProgress sweep) {
    final total = sweep.total;
    switch (sweep.phase) {
      case 'learning':
        return total == null
            ? appStrings.sweepStarting
            : appStrings.sweepLearningProgress(sweep.done, total);
      default:
        if (total != null) {
          return appStrings.sweepReadingProgress(sweep.done, total);
        }
        return sweep.done == 0
            ? appStrings.sweepStarting
            : appStrings.sweepReadingFound(sweep.done);
    }
  }
}

class _OfficialIntegrationIcon extends StatelessWidget {
  _OfficialIntegrationIcon({required OfficialIntegrationItem item})
    : icon = item.icon,
      label = item.label,
      size = 44;

  /// A badge for something that is not an integration itself, such as a mail
  /// provider inside one.
  const _OfficialIntegrationIcon.named({
    required this.icon,
    required this.label,
    this.size = 44,
  });

  final String icon;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (icon) {
      'neorecall' => const Color(0xFFD98AA6),
      'nextcloud' => const Color(0xFF0082C9),
      'google' => const Color(0xFF4285F4),
      'microsoft' => const Color(0xFF0078D4),
      'apple' => const Color(0xFF8E8E93),
      'email' => const Color(0xFF2F9E8F),
      'phone' => const Color(0xFF7C5CDB),
      'calendar' => const Color(0xFFE8833A),
      'home_assistant' => const Color(0xFF41BDF5),
      'password' => const Color(0xFF175DDC),
      'trello' => const Color(0xFF0C66E4),
      'news' => const Color(0xFFE5484D),
      _ => _accent,
    };
    final glyph = switch (icon) {
      'email' || 'mail' => Icons.alternate_email_rounded,
      'calendar' => Icons.event_rounded,
      'phone' => Icons.smartphone_rounded,
      _ => null,
    };
    final letter = switch (icon) {
      'neorecall' => 'R',
      'nextcloud' => 'N',
      'google' => 'G',
      'microsoft' => 'M',
      'home_assistant' => 'H',
      'password' => 'B',
      'trello' => 'T',
      'news' => 'W',
      _ => label.isNotEmpty ? label[0] : '?',
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      alignment: Alignment.center,
      child: glyph != null
          ? Icon(glyph, color: color, size: size * 0.5)
          : Text(
              letter,
              style: TextStyle(
                color: color,
                fontSize: size * 0.45,
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
