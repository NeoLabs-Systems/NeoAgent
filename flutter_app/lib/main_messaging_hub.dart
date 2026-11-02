part of 'main.dart';

// Feeds the messaging hub from the app's state. The hub itself knows nothing of
// the controller; this file is where its actions turn into controller calls.

class MessagingPanel extends StatefulWidget {
  const MessagingPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MessagingPanel> createState() => _MessagingPanelState();
}

class _MessagingPanelState extends State<MessagingPanel> {
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // An admin can set up a shared account while the app stays open.
    unawaited(_controller.refreshSharedMessagingOptions().then(_redraw));
  }

  void _redraw(void _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _SettingsHighlightScope.of(context)?.anchor;
    final qr = _controller.pendingMessagingQr;
    return _SettingsAnchor(
      id: 'channels',
      child: MessagingHub(
        agentName: _controller.activeAgentLabel,
        apps: messagingHubApps(context, _controller),
        offers: messagingHubOffers(context, _controller),
        pendingQr: qr == null ? null : MessagingQrPanel(qrState: qr),
        moreSettingsExpanded:
            highlight == 'participation' || highlight == 'delivery',
        moreSettings: <Widget>[
          _GroupChatDefaults(controller: _controller),
          if (_controller.ignoredChats.isNotEmpty)
            _IgnoredChatsPanel(controller: _controller),
          _MessagingActivityPanel(messages: _controller.messagingMessages),
        ],
      ),
    );
  }
}

/// Every app, in the catalogue's order, with what a person can do with it.
List<HubApp> messagingHubApps(
  BuildContext context,
  NeoAgentController controller,
) {
  return messagingPlatforms
      .map((platform) {
        final status =
            controller.messagingStatuses[platform.id] ??
            MessagingPlatformStatus.empty(platform.id);
        final state = hubStateFor(status.status);
        final authLabel = status.identityLabel;
        return HubApp(
          id: platform.id,
          label: platform.label,
          subtitle: platform.subtitle,
          icon: platform.icon,
          color: platform.accent,
          state: state,
          identity: authLabel,
          isShared: status.isShared,
          // A broken connection is theirs to repair, not a reason to switch them
          // to the shared account.
          onConnect: state == HubAppState.attention
              ? () =>
                    _openPersonalMessagingConfig(context, controller, platform)
              : () => openMessagingConfig(context, controller, platform),
          menu: state == HubAppState.available || state == HubAppState.disabled
              ? const <HubMenuAction>[]
              : _manageActions(context, controller, platform, status),
        );
      })
      .toList(growable: false);
}

List<HubMenuAction> _manageActions(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
  MessagingPlatformStatus status,
) {
  final selfChatOnly =
      platform.id == 'whatsapp' && readWhatsAppSelfChatMode(controller);
  final shared = status.isShared;
  return <HubMenuAction>[
    if (!shared && !selfChatOnly)
      HubMenuAction(
        label: appStrings.whoCanMessage,
        onSelected: () => _editMessagingAccess(context, controller, platform),
      ),
    if (!shared && platform.id == 'whatsapp')
      HubMenuAction(
        label: appStrings.chatMode,
        onSelected: () =>
            _openPersonalMessagingConfig(context, controller, platform),
      ),
    if (!shared && controller.sharedMessagingOptions[platform.id] != null)
      HubMenuAction(
        label: appStrings.sharedMessagingUseShared,
        onSelected: () => _startSharedLink(context, controller, platform),
      ),
    if (status.isConnected && !shared)
      HubMenuAction(
        label: appStrings.logout,
        onSelected: () => controller.logoutMessagingPlatform(platform.id),
      ),
    HubMenuAction(
      label: appStrings.messagingHubDisconnect,
      destructive: true,
      onSelected: () => controller.disconnectMessagingPlatform(platform.id),
    ),
  ];
}

/// Shared accounts this person can still link to.
List<HubLinkOffer> messagingHubOffers(
  BuildContext context,
  NeoAgentController controller,
) {
  final offers = <HubLinkOffer>[];
  final apps = messagingHubApps(context, controller);
  for (final app in apps) {
    final option = controller.sharedMessagingOptions[app.id];
    final platform = _messagingPlatformById(app.id);
    if (option == null || platform == null || app.isMine) continue;
    offers.add(
      HubLinkOffer(
        app: app,
        accountLabel: option.accountLabel,
        onLink: () => _startSharedLink(context, controller, platform),
        onUseOwnAccount: option.personalAllowed
            ? () => _openPersonalMessagingConfig(context, controller, platform)
            : null,
      ),
    );
  }
  return offers;
}

Future<void> _editMessagingAccess(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  final catalog = await controller.loadMessagingAccessCatalog(
    platform.id,
    force: true,
  );
  if (!context.mounted) return;
  await _showMessagingAccessPolicyDialog(
    context,
    platform: platform,
    agentName: controller.activeAgentLabel,
    initialCatalog: catalog,
    onRefreshCatalog: () =>
        controller.loadMessagingAccessCatalog(platform.id, force: true),
    onSave: (policy) =>
        controller.saveMessagingAccessPolicy(platform.id, policy),
    onLoadDecisions: () => controller.loadBehaviorDecisions(platform.id),
  );
}

/// What the link flow needs for [platform], whether it runs in a dialog or in
/// place.
SharedLinkSession sharedLinkSessionFor(
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
  SharedMessagingOption option,
) {
  return SharedLinkSession(
    platformLabel: platform.label,
    platformIcon: platform.icon,
    platformColor: platform.accent,
    option: option,
    movesExistingLink:
        option.linkedAgentId != null &&
        option.linkedAgentId != controller._scopedAgentId,
    updates: controller,
    startLink: () => controller.startSharedMessagingLink(platform.id),
    linkedIdentity: () {
      final status = controller.messagingStatuses[platform.id];
      if (status?.isShared != true) return null;
      return status!.identityLabel ?? platform.label;
    },
    failure: () => controller.sharedMessagingLinkFailure,
    describeError: controller.friendlyErrorMessage,
  );
}

Future<void> _startSharedLink(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  final option = controller.sharedMessagingOptions[platform.id];
  if (option == null) return;
  await showSharedLinkDialog(
    context,
    sharedLinkSessionFor(controller, platform, option),
  );
}

/// Connecting from anywhere: the shared account when the server offers one,
/// because that is one tap, otherwise the platform's own setup.
Future<void> openMessagingConfig(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  await controller.refreshSharedMessagingOptions();
  if (!context.mounted) return;
  final status = controller.messagingStatuses[platform.id];
  if (controller.sharedMessagingOptions[platform.id] != null &&
      status?.isConnected != true) {
    return _startSharedLink(context, controller, platform);
  }
  return _openPersonalMessagingConfig(context, controller, platform);
}

/// The person's own bot or number, reached from Advanced.
Future<void> openPersonalMessagingConfig(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) {
  return _openPersonalMessagingConfig(context, controller, platform);
}
