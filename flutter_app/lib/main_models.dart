part of 'main.dart';

final messagingPlatforms = <MessagingPlatformDescriptor>[
  MessagingPlatformDescriptor(
    id: 'whatsapp',
    label: 'WhatsApp',
    subtitle: appStrings.qrBasedPhoneLinking,
    accent: Color(0xFF25D366),
    connectMethod: MessagingConnectMethod.qr,
    icon: Icons.chat_bubble,
  ),
  MessagingPlatformDescriptor(
    id: 'telegram',
    label: 'Telegram',
    subtitle: appStrings.botTokenAndApprovedChats,
    accent: Color(0xFF2AABEE),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.send_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'botToken',
        label: appStrings.botToken,
        hint: appStrings.fromBotfatherAfterYouCreateThe,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'discord',
    label: 'Discord',
    subtitle: appStrings.botTokenAndServerChannelAccess,
    accent: Color(0xFF5865F2),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.sports_esports_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'token',
        label: appStrings.botToken,
        hint: appStrings.fromTheDiscordDeveloperPortalUnder,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'slack',
    label: 'Slack',
    subtitle: appStrings.botTokenEventsApiAndChannel,
    accent: Color(0xFF36C5F0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.tag_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'botToken',
        label: appStrings.botToken,
        hint: appStrings.startsWithXoxbFromYourSlack,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'signingSecret',
        label: appStrings.signingSecret,
        hint: appStrings.usedToVerifyThatIncomingSlack,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalExtraSecretIfYouProtect,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'google_chat',
    label: appStrings.googleChat,
    subtitle: appStrings.spaceWebhookAndAppCallbackSupport,
    accent: Color(0xFF34A853),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.forum_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: appStrings.outgoingWebhookUrl,
        hint: appStrings.theGoogleChatSpaceWebhookThis,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingChat,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'defaultTo',
        label: appStrings.defaultSpace,
        hint: appStrings.spaceOrChatIdUsedWhen,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'teams',
    label: appStrings.microsoftTeams,
    subtitle: appStrings.incomingWebhookAndOutgoingCallbackSupport,
    accent: Color(0xFF6264A7),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.groups_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: appStrings.outgoingWebhookUrl,
        hint: appStrings.theTeamsIncomingWebhookThisAgent,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingTeams,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'defaultTo',
        label: appStrings.defaultConversation,
        hint: appStrings.conversationIdUsedWhenThisAgent,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'matrix',
    label: 'Matrix',
    subtitle: appStrings.homeserverTokenWithRoomPolling,
    accent: Color(0xFF0DBD8B),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.grid_view_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'homeserver',
        label: appStrings.homeserverUrl,
        hint: appStrings.forExampleHttpsMatrixOrg,
      ),
      MessagingConfigField(
        key: 'accessToken',
        label: appStrings.accessToken2,
        hint: appStrings.fromTheMatrixClientOrBot,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'userId',
        label: appStrings.botUserId,
        hint: appStrings.usuallyLooksLikeBotMatrixOrg,
      ),
      MessagingConfigField(
        key: 'pollIntervalMs',
        label: appStrings.checkForMessagesEveryMs,
        hint: appStrings.howOftenThisAgentLooksFor,
        defaultValue: '5000',
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'signal',
    label: 'Signal',
    subtitle: appStrings.signalCliRestApiBridge,
    accent: Color(0xFF3A76F0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.lock_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'restUrl',
        label: appStrings.signalCliServerUrl,
        hint: appStrings.theRestEndpointForYourSignal,
      ),
      MessagingConfigField(
        key: 'account',
        label: appStrings.accountNumber,
        hint: appStrings.theSignalPhoneNumberThisBot,
      ),
      MessagingConfigField(
        key: 'pollEnabled',
        label: appStrings.checkForNewMessagesAutomatically,
        hint: appStrings.turnOnIfSignalShouldKeep,
        kind: MessagingConfigFieldKind.boolean,
      ),
      MessagingConfigField(
        key: 'pollIntervalMs',
        label: appStrings.checkForMessagesEveryMs,
        hint: appStrings.howOftenThisAgentLooksFor2,
        defaultValue: '10000',
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'imessage',
    label: 'iMessage',
    subtitle: appStrings.bluebubblesCompatibleBridge,
    accent: Color(0xFF007AFF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.sms_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'serverUrl',
        label: appStrings.bluebubblesServerUrl,
        hint: appStrings.theAddressOfYourBluebubblesServer,
      ),
      MessagingConfigField(
        key: 'password',
        label: appStrings.passwordOrApiKey,
        hint: appStrings.thePasswordYouSetInBluebubbles,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'sendPath',
        label: appStrings.sendPath,
        hint: appStrings.leaveAsTheDefaultUnlessYou,
        defaultValue: '/api/v1/message/text',
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingImessage,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'bluebubbles',
    label: 'BlueBubbles',
    subtitle: appStrings.directBluebubblesImessageBridge,
    accent: Color(0xFF0A84FF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.bubble_chart_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'serverUrl',
        label: appStrings.bluebubblesServerUrl,
        hint: appStrings.theAddressOfYourBluebubblesServer,
      ),
      MessagingConfigField(
        key: 'password',
        label: appStrings.passwordOrApiKey,
        hint: appStrings.thePasswordYouSetInBluebubbles,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'sendPath',
        label: appStrings.sendPath,
        hint: appStrings.leaveAsTheDefaultUnlessYou,
        defaultValue: '/api/v1/message/text',
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingImessage,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'irc',
    label: 'IRC',
    subtitle: appStrings.serverNickChannelAndOptionalTls,
    accent: Color(0xFF7E57C2),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.terminal_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'server',
        label: 'Server',
        hint: appStrings.hostnameOfTheIrcNetworkFor,
      ),
      MessagingConfigField(key: 'port', label: appStrings.port, defaultValue: '6667'),
      MessagingConfigField(key: 'nick', label: appStrings.nickname),
      MessagingConfigField(key: 'password', label: appStrings.password, obscure: true),
      MessagingConfigField(
        key: 'channels',
        label: appStrings.channels,
        hint: appStrings.commaSeparatedForExampleGeneralHelp,
      ),
      MessagingConfigField(
        key: 'tls',
        label: appStrings.useASecureConnectionTls,
        kind: MessagingConfigFieldKind.boolean,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'twitch',
    label: 'Twitch',
    subtitle: appStrings.twitchChatOverIrc,
    accent: Color(0xFF9146FF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.live_tv_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'nick', label: appStrings.botUsername),
      MessagingConfigField(
        key: 'oauthToken',
        label: appStrings.oauthToken,
        hint: appStrings.fromTwitchappsComTmiOrYour,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'channels',
        label: appStrings.channels,
        hint: appStrings.commaSeparatedChannelNamesWithoutThe,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'line',
    label: 'LINE',
    subtitle: appStrings.messagingApiPushAndWebhookEvents,
    accent: Color(0xFF06C755),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.chat_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'channelAccessToken',
        label: appStrings.channelAccessToken,
        hint: appStrings.fromTheLineDevelopersConsole,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingLine,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'mattermost',
    label: 'Mattermost',
    subtitle: appStrings.webhookOrRestChannelPosting,
    accent: Color(0xFF0058CC),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.forum_outlined,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: appStrings.outgoingWebhookUrl,
        hint: appStrings.theMattermostIncomingWebhookThisAgent,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'baseUrl',
        label: appStrings.serverUrl,
        hint: appStrings.yourMattermostSiteUrlIfYou,
      ),
      MessagingConfigField(
        key: 'token',
        label: appStrings.accessToken2,
        hint: appStrings.personalAccessTokenForTheMattermost,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingMattermost,
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'github',
    label: 'GitHub',
    subtitle: appStrings.answersMentionsOnIssuesAndPull,
    accent: Color(0xFF8B949E),
    connectMethod: MessagingConnectMethod.integration,
    icon: Icons.code_rounded,
    integrationProvider: 'github',
    integrationApp: 'mentions',
  ),
  ...longTailMessagingPlatforms,
];

List<MessagingPlatformDescriptor> longTailMessagingPlatforms =
    <MessagingPlatformDescriptor>[
      MessagingPlatformDescriptor(
        id: 'feishu',
        label: 'Feishu',
        subtitle: appStrings.configurableWebhookBridge,
        accent: Color(0xFF3370FF),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.webhook_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'nextcloud_talk',
        label: appStrings.nextcloudTalk,
        subtitle: appStrings.configurableTalkWebhookBridge,
        accent: Color(0xFF0082C9),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.cloud_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'nostr',
        label: 'Nostr',
        subtitle: appStrings.configurableRelayOrWebhookBridge,
        accent: Color(0xFF9C27B0),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.hub_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'synology_chat',
        label: appStrings.synologyChat,
        subtitle: appStrings.configurableWebhookBridge,
        accent: Color(0xFF1E88E5),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.storage_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'tlon',
        label: 'Tlon',
        subtitle: appStrings.configurableWebhookBridge,
        accent: Color(0xFF111111),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.blur_on_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'zalo',
        label: 'Zalo',
        subtitle: appStrings.configurableWebhookBridge,
        accent: Color(0xFF0068FF),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.message_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'zalo_personal',
        label: appStrings.zaloPersonal,
        subtitle: appStrings.configurablePersonalWebhookBridge,
        accent: Color(0xFF0288D1),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.person_pin_circle_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'wechat',
        label: 'WeChat',
        subtitle: appStrings.configurableWebhookBridge,
        accent: Color(0xFF07C160),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.chat_bubble_outline_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'webchat',
        label: 'WebChat',
        subtitle: appStrings.configurableWebInboxBridge,
        accent: Color(0xFF00A1F1),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.public_rounded,
        configFields: genericWebhookConfigFields,
      ),
    ];

List<MessagingConfigField> genericWebhookConfigFields =
    <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: appStrings.outgoingWebhookUrl,
        hint: appStrings.whereThisAgentShouldSendReplies,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'outboundUrl',
        label: appStrings.customOutgoingUrl,
        hint: appStrings.optionalOverrideIfTheWebhookUrl,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'token',
        label: appStrings.accessToken2,
        hint: appStrings.ifTheServiceRequiresAToken,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: appStrings.webhookSecret,
        hint: appStrings.optionalSecretToVerifyIncomingEvents,
        obscure: true,
      ),
      MessagingConfigField(
        key: 'contentField',
        label: appStrings.messageTextField,
        hint: appStrings.jsonFieldThatContainsTheMessage,
        defaultValue: 'text',
      ),
      MessagingConfigField(
        key: 'recipientField',
        label: appStrings.recipientField,
        hint: appStrings.jsonFieldThatIdentifiesWhoThe,
      ),
      MessagingConfigField(
        key: 'headers',
        label: appStrings.customHeadersJson,
        hint: appStrings.onlyNeededIfTheServiceAsks,
        kind: MessagingConfigFieldKind.multiline,
      ),
      MessagingConfigField(
        key: 'bodyTemplate',
        label: appStrings.messageBodyTemplateJson,
        hint: appStrings.onlyNeededIfYouWantTo,
        kind: MessagingConfigFieldKind.multiline,
      ),
    ];

/// `integration` platforms sign in through an official integration's OAuth
/// flow instead of asking for tokens in a form.
enum MessagingConnectMethod { qr, config, integration }

enum MessagingConfigFieldKind { text, password, multiline, boolean }

class MessagingConfigField {
  const MessagingConfigField({
    required this.key,
    required this.label,
    this.hint,
    this.kind = MessagingConfigFieldKind.text,
    this.obscure = false,
    this.defaultValue,
    this.settingsKey,
    this.includeInConfig = true,
  });

  final String key;
  final String label;
  final String? hint;
  final MessagingConfigFieldKind kind;
  final bool obscure;
  final String? defaultValue;
  final String? settingsKey;
  final bool includeInConfig;

  String get storageKey => settingsKey ?? key;
}

class MessagingPlatformDescriptor {
  const MessagingPlatformDescriptor({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.connectMethod,
    required this.icon,
    this.configFields = const <MessagingConfigField>[],
    this.accessCapabilities,
    this.integrationProvider,
    this.integrationApp,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final MessagingConnectMethod connectMethod;
  final IconData icon;
  final List<MessagingConfigField> configFields;
  final MessagingAccessCapabilities? accessCapabilities;

  /// Official integration provider and app whose connection this platform uses
  /// when [connectMethod] is [MessagingConnectMethod.integration].
  final String? integrationProvider;
  final String? integrationApp;

  String get settingsKey => '${id}_config';
}

class MessagingPlatformGroup {
  const MessagingPlatformGroup({
    required this.label,
    required this.subtitle,
    required this.ids,
  });

  final String label;
  final String subtitle;
  final List<String> ids;
}

class MessagingPlatformStatus {
  const MessagingPlatformStatus({
    required this.platform,
    required this.status,
    this.lastConnected,
    this.authInfo = const <String, dynamic>{},
  });

  factory MessagingPlatformStatus.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    return MessagingPlatformStatus(
      platform: platform,
      status:
          json['status']?.toString().ifEmpty('not_configured') ??
          'not_configured',
      lastConnected: _parseOptionalTimestamp(json['lastConnected']?.toString()),
      authInfo: _jsonMap(json['authInfo']),
    );
  }

  factory MessagingPlatformStatus.empty(String platform) {
    return MessagingPlatformStatus(
      platform: platform,
      status: 'not_configured',
    );
  }

  final String platform;
  final String status;
  final DateTime? lastConnected;
  final Map<String, dynamic> authInfo;

  bool get isConnected => status == 'connected';
  bool get isConnecting =>
      status == 'connecting' ||
      status == 'reconnecting' ||
      status == 'awaiting_qr';

  String get statusLabel => status.replaceAll('_', ' ');

  String get authLabel {
    for (final key in <String>['phoneNumber', 'tag', 'username', 'label']) {
      final value = authInfo[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return key == 'username' ? '@$value' : value;
      }
    }
    if (lastConnected != null) {
      return appStrings.lastSeenArg1(_formatTimestamp(lastConnected!));
    }
    return appStrings.notConnected;
  }

  Color get badgeColor {
    switch (status) {
      case 'connected':
        return _success;
      case 'awaiting_qr':
      case 'connecting':
      case 'reconnecting':
        return _warning;
      case 'logged_out':
        return _danger;
      default:
        return _textSecondary;
    }
  }
}

class MessagingMessage {
  const MessagingMessage({
    required this.platform,
    required this.content,
    required this.createdAt,
    required this.outgoing,
    this.chatId,
    this.sender,
    this.senderName,
    this.target,
    this.agentId,
  });

  factory MessagingMessage.fromJson(Map<dynamic, dynamic> json) {
    final metadata = _jsonMap(_decodeMaybeJson(json['metadata']));
    final sender = (metadata['sender']?.toString() ?? '').trim();
    final senderName =
        (metadata['senderName']?.toString() ??
                metadata['sender_name']?.toString() ??
                json['sender_name']?.toString() ??
                '')
            .trim();
    final chatId =
        (json['platform_chat_id']?.toString() ??
                metadata['chatId']?.toString() ??
                metadata['chat_id']?.toString() ??
                '')
            .trim();
    return MessagingMessage(
      platform: json['platform']?.toString() ?? 'web',
      content: json['content']?.toString() ?? '',
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      outgoing: json['role']?.toString() == 'assistant',
      chatId: chatId.isEmpty ? null : chatId,
      sender: sender.isEmpty ? null : sender,
      senderName: senderName.isEmpty ? null : senderName,
      target: chatId.isEmpty ? null : chatId,
      agentId: json['agent_id']?.toString() ?? json['agentId']?.toString(),
    );
  }

  factory MessagingMessage.fromSocket(
    Map<String, dynamic> json, {
    required bool outgoing,
  }) {
    return MessagingMessage(
      platform: json['platform']?.toString() ?? 'web',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.now(),
      outgoing: outgoing,
      chatId: json['chatId']?.toString() ?? json['to']?.toString(),
      sender: json['sender']?.toString(),
      senderName: json['senderName']?.toString(),
      target: json['to']?.toString(),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
    );
  }

  factory MessagingMessage.fromBlockedNotice(BlockedSenderNotice notice) {
    final summary = <String>[
      appStrings.blockedIncomingMessageFromArg1(notice.senderLabel),
      if (notice.meta.isNotEmpty) notice.meta,
      if (notice.suggestions.isNotEmpty)
        appStrings.suggestionsArg1(notice.suggestions.map((item) => item.label).join(', ')),
      appStrings.updateTheAccessListToAllow,
    ].join('\n');

    return MessagingMessage(
      platform: notice.platform,
      content: summary,
      createdAt: DateTime.now(),
      outgoing: false,
      chatId: notice.chatId,
      sender: notice.sender,
      senderName: notice.senderName,
    );
  }

  final String platform;
  final String content;
  final DateTime createdAt;
  final bool outgoing;
  final String? chatId;
  final String? sender;
  final String? senderName;
  final String? target;
  final String? agentId;

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get senderLabel {
    if (outgoing) {
      return target?.ifEmpty(appStrings.outgoingMessage) ?? appStrings.outgoingMessage;
    }
    return senderName?.ifEmpty(sender ?? platform.toUpperCase()) ??
        sender?.ifEmpty(platform.toUpperCase()) ??
        platform.toUpperCase();
  }
}

class TaskDeliveryTarget {
  const TaskDeliveryTarget({
    required this.platform,
    required this.platformLabel,
    required this.to,
    required this.label,
    required this.subtitle,
    required this.source,
    required this.connected,
    required this.supportsDelivery,
  });

  factory TaskDeliveryTarget.fromJson(Map<dynamic, dynamic> json) {
    final platform = json['platform']?.toString() ?? '';
    final to = json['to']?.toString() ?? '';
    return TaskDeliveryTarget(
      platform: platform,
      platformLabel:
          json['platformLabel']?.toString().ifEmpty(platform.toUpperCase()) ??
          platform.toUpperCase(),
      to: to,
      label: json['label']?.toString().ifEmpty(to) ?? to,
      subtitle: json['subtitle']?.toString() ?? '',
      source: json['source']?.toString().ifEmpty('discovered') ?? 'discovered',
      connected: json['connected'] != false,
      supportsDelivery: json['supportsDelivery'] != false,
    );
  }

  final String platform;
  final String platformLabel;
  final String to;
  final String label;
  final String subtitle;
  final String source;
  final bool connected;
  final bool supportsDelivery;

  String get id => '$platform:$to';
  bool get selectable => connected && supportsDelivery;

  String get sourceLabel {
    switch (source) {
      case 'default':
        return appStrings.default2;
      case 'recent':
        return 'Recent';
      case 'manual':
        return 'Manual';
      default:
        return 'Discovered';
    }
  }
}

class MessagingQrState {
  const MessagingQrState({required this.platform, required this.qr});

  final String platform;
  final String qr;

  String get platformLabel {
    for (final item in messagingPlatforms) {
      if (item.id == platform) {
        return item.label;
      }
    }
    return platform;
  }
}

class BehaviorDecisionEntry {
  const BehaviorDecisionEntry({
    required this.at,
    required this.chatId,
    required this.decision,
    required this.reasonCodes,
    required this.needScore,
    required this.tokenPath,
    required this.preview,
    required this.wasMentioned,
    required this.repliedToAgent,
    this.chatName,
    this.serverName,
    this.senderName,
    this.model,
    this.needThreshold,
    this.systemOneSpeak,
    this.systemOneForSomeoneElse,
  });

  factory BehaviorDecisionEntry.fromJson(Map<String, dynamic> json) {
    final systemOneScores = json['systemOneScores'] is Map
        ? Map<String, dynamic>.from(json['systemOneScores'] as Map)
        : null;
    return BehaviorDecisionEntry(
      at:
          DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      chatId: json['chatId']?.toString() ?? '',
      chatName: json['chatName']?.toString(),
      serverName: json['serverName']?.toString(),
      senderName: json['senderName']?.toString(),
      preview: json['preview']?.toString() ?? '',
      wasMentioned: json['wasMentioned'] == true,
      repliedToAgent: json['repliedToAgent'] == true,
      decision: json['decision']?.toString() ?? 'stay_silent',
      reasonCodes: json['reasonCodes'] is List
          ? (json['reasonCodes'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      needScore: (json['needScore'] as num?)?.toDouble() ?? 0,
      tokenPath: json['tokenPath']?.toString() ?? '',
      model: json['model']?.toString(),
      needThreshold: (json['needThreshold'] as num?)?.toDouble(),
      systemOneSpeak: systemOneScores?['speak'] is num
          ? (systemOneScores!['speak'] as num).toDouble()
          : null,
      systemOneForSomeoneElse: systemOneScores?['forSomeoneElse'] is num
          ? (systemOneScores!['forSomeoneElse'] as num).toDouble()
          : null,
    );
  }

  final DateTime at;
  final String chatId;
  final String? chatName;
  final String? serverName;
  final String? senderName;
  final String preview;
  final bool wasMentioned;
  final bool repliedToAgent;
  final String decision;
  final List<String> reasonCodes;
  final double needScore;
  final String tokenPath;
  final String? model;
  final double? needThreshold;
  final double? systemOneSpeak;
  final double? systemOneForSomeoneElse;

  bool get spoke => decision == 'speak';

  // A SystemOne model scores the message itself; no language model runs for
  // these turns.
  bool get judgedBySystemOne => tokenPath == 'system_one_gate';

  bool get judgedByLlm => tokenPath == 'gate_only';
}

class MessagingAccessRule {
  const MessagingAccessRule({
    required this.scope,
    required this.value,
    this.label,
    this.spaceScope,
    this.spaceValue,
    this.spaceLabel,
  });

  factory MessagingAccessRule.fromJson(Map<String, dynamic> json) {
    return MessagingAccessRule(
      scope: json['scope']?.toString() ?? 'chat',
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString(),
      spaceScope: json['spaceScope']?.toString(),
      spaceValue: json['spaceValue']?.toString(),
      spaceLabel: json['spaceLabel']?.toString(),
    );
  }

  final String scope;
  final String value;
  final String? label;
  final String? spaceScope;
  final String? spaceValue;
  final String? spaceLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scope': scope,
    'value': value,
    if (label != null && label!.trim().isNotEmpty) 'label': label,
    if (spaceScope != null && spaceScope!.trim().isNotEmpty)
      'spaceScope': spaceScope,
    if (spaceValue != null && spaceValue!.trim().isNotEmpty)
      'spaceValue': spaceValue,
    if (spaceLabel != null && spaceLabel!.trim().isNotEmpty)
      'spaceLabel': spaceLabel,
  };

  String get id => '$scope:$value:${spaceScope ?? ''}:${spaceValue ?? ''}';

  String get displayLabel =>
      messagingRuleDisplayLabel(label: label, value: value);

  bool get isSharedSpace {
    switch (scope) {
      case 'user':
      case 'dm':
      case 'phone_number':
      case 'role':
        return false;
      default:
        return !looksLikeDirectMessagingValue(value);
    }
  }

  String get spaceDisplayLabel =>
      spaceLabel?.ifEmpty(spaceValue ?? '') ?? spaceValue ?? '';

  String get scopeLabel {
    switch (scope) {
      case 'phone_number':
        return 'Number';
      case 'server':
        return appStrings.server;
      case 'channel':
        return appStrings.channel;
      case 'group':
        return 'Group';
      case 'room':
        return 'Room';
      case 'role':
        return 'Role';
      case 'dm':
        return 'DM';
      case 'user':
        return 'User';
      default:
        return appStrings.chat;
    }
  }
}

class MessagingSharedParticipationRule {
  const MessagingSharedParticipationRule({
    required this.scope,
    required this.value,
    required this.allowUntagged,
    this.label,
  });

  factory MessagingSharedParticipationRule.fromJson(Map<String, dynamic> json) {
    return MessagingSharedParticipationRule(
      scope: json['scope']?.toString() ?? 'chat',
      value: json['value']?.toString() ?? '',
      allowUntagged: json['allowUntagged'] == true,
      label: json['label']?.toString(),
    );
  }

  final String scope;
  final String value;
  final bool allowUntagged;
  final String? label;

  String get id => '$scope:$value';
  String get displayLabel =>
      messagingRuleDisplayLabel(label: label, value: value);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scope': scope,
    'value': value,
    'allowUntagged': allowUntagged,
    if (label != null && label!.trim().isNotEmpty) 'label': label,
  };
}

class MessagingAccessPolicy {
  const MessagingAccessPolicy({
    required this.schemaVersion,
    required this.directPolicy,
    required this.sharedPolicy,
    required this.defaultAllowUntaggedInShared,
    required this.directRules,
    required this.sharedSpaceRules,
    required this.sharedActorRules,
    required this.sharedMemberRules,
    required this.sharedParticipationRules,
  });

  factory MessagingAccessPolicy.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 2;
    return MessagingAccessPolicy(
      schemaVersion: schemaVersion,
      directPolicy:
          json['directPolicy']?.toString().ifEmpty('allowlist') ?? 'allowlist',
      sharedPolicy:
          json['sharedPolicy']?.toString().ifEmpty('allowlist') ?? 'allowlist',
      defaultAllowUntaggedInShared: schemaVersion < 3
          ? json['requireMentionInShared'] != true
          : json['defaultAllowUntaggedInShared'] == true,
      directRules:
          (json['directRules'] is List
                  ? json['directRules'] as List
                  : const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => MessagingAccessRule.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      sharedSpaceRules:
          (json['sharedSpaceRules'] is List
                  ? json['sharedSpaceRules'] as List
                  : const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => MessagingAccessRule.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      sharedActorRules:
          (json['sharedActorRules'] is List
                  ? json['sharedActorRules'] as List
                  : const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => MessagingAccessRule.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      sharedMemberRules:
          (json['sharedMemberRules'] is List
                  ? json['sharedMemberRules'] as List
                  : const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => MessagingAccessRule.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      sharedParticipationRules:
          (json['sharedParticipationRules'] is List
                  ? json['sharedParticipationRules'] as List
                  : const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => MessagingSharedParticipationRule.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.value.isNotEmpty)
              .toList(growable: false),
    );
  }

  const MessagingAccessPolicy.defaults({
    this.schemaVersion = 3,
    this.directPolicy = 'allowlist',
    this.sharedPolicy = 'allowlist',
    this.defaultAllowUntaggedInShared = false,
    this.directRules = const <MessagingAccessRule>[],
    this.sharedSpaceRules = const <MessagingAccessRule>[],
    this.sharedActorRules = const <MessagingAccessRule>[],
    this.sharedMemberRules = const <MessagingAccessRule>[],
    this.sharedParticipationRules = const <MessagingSharedParticipationRule>[],
  });

  final int schemaVersion;
  final String directPolicy;
  final String sharedPolicy;
  final bool defaultAllowUntaggedInShared;
  final List<MessagingAccessRule> directRules;
  final List<MessagingAccessRule> sharedSpaceRules;
  final List<MessagingAccessRule> sharedActorRules;
  final List<MessagingAccessRule> sharedMemberRules;
  final List<MessagingSharedParticipationRule> sharedParticipationRules;

  MessagingAccessPolicy copyWith({
    int? schemaVersion,
    String? directPolicy,
    String? sharedPolicy,
    bool? defaultAllowUntaggedInShared,
    List<MessagingAccessRule>? directRules,
    List<MessagingAccessRule>? sharedSpaceRules,
    List<MessagingAccessRule>? sharedActorRules,
    List<MessagingAccessRule>? sharedMemberRules,
    List<MessagingSharedParticipationRule>? sharedParticipationRules,
  }) {
    return MessagingAccessPolicy(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      directPolicy: directPolicy ?? this.directPolicy,
      sharedPolicy: sharedPolicy ?? this.sharedPolicy,
      defaultAllowUntaggedInShared:
          defaultAllowUntaggedInShared ?? this.defaultAllowUntaggedInShared,
      directRules: directRules ?? this.directRules,
      sharedSpaceRules: sharedSpaceRules ?? this.sharedSpaceRules,
      sharedActorRules: sharedActorRules ?? this.sharedActorRules,
      sharedMemberRules: sharedMemberRules ?? this.sharedMemberRules,
      sharedParticipationRules:
          sharedParticipationRules ?? this.sharedParticipationRules,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'directPolicy': directPolicy,
    'sharedPolicy': sharedPolicy,
    'defaultAllowUntaggedInShared': defaultAllowUntaggedInShared,
    'directRules': directRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedSpaceRules': sharedSpaceRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedActorRules': sharedActorRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedMemberRules': sharedMemberRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedParticipationRules': sharedParticipationRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
  };

  int get totalRuleCount =>
      directRules.length +
      sharedSpaceRules.length +
      sharedActorRules.length +
      sharedMemberRules.length;
}

class MessagingAccessCapabilities {
  const MessagingAccessCapabilities({
    this.supportsDirectPolicy = true,
    this.supportsSharedPolicy = true,
    this.supportsMentionGate = false,
    this.supportsUntaggedGroupToggle = true,
    this.supportsDiscovery = false,
    this.directRuleScopes = const <String>[],
    this.sharedSpaceRuleScopes = const <String>[],
    this.sharedActorRuleScopes = const <String>[],
    this.manualEntryHint = '',
    this.sharedModes = const <String>['allowlist', 'open', 'disabled'],
    this.requireSharedActor = false,
    this.mentionOnly = false,
  });

  factory MessagingAccessCapabilities.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic value) {
      if (value is! List) return const <String>[];
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return MessagingAccessCapabilities(
      supportsDirectPolicy: json['supportsDirectPolicy'] != false,
      supportsSharedPolicy: json['supportsSharedPolicy'] != false,
      supportsMentionGate: json['supportsMentionGate'] == true,
      supportsUntaggedGroupToggle: json['supportsUntaggedGroupToggle'] != false,
      supportsDiscovery: json['supportsDiscovery'] == true,
      directRuleScopes: stringList(json['directRuleScopes']),
      sharedSpaceRuleScopes: stringList(json['sharedSpaceRuleScopes']),
      sharedActorRuleScopes: stringList(json['sharedActorRuleScopes']),
      manualEntryHint: json['manualEntryHint']?.toString() ?? '',
      sharedModes: json['sharedModes'] is List
          ? stringList(json['sharedModes'])
          : const <String>['allowlist', 'open', 'disabled'],
      requireSharedActor: json['requireSharedActor'] == true,
      mentionOnly: json['mentionOnly'] == true,
    );
  }

  final bool supportsDirectPolicy;
  final bool supportsSharedPolicy;
  final bool supportsMentionGate;
  final bool supportsUntaggedGroupToggle;
  final bool supportsDiscovery;
  final List<String> directRuleScopes;
  final List<String> sharedSpaceRuleScopes;
  final List<String> sharedActorRuleScopes;
  final String manualEntryHint;

  /// Modes the owner may choose for groups; public platforms leave out 'open'.
  final List<String> sharedModes;

  /// When true, a group rule only says where the agent listens and every
  /// sender still needs their own approval.
  final bool requireSharedActor;
  final bool mentionOnly;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'supportsDirectPolicy': supportsDirectPolicy,
    'supportsSharedPolicy': supportsSharedPolicy,
    'supportsMentionGate': supportsMentionGate,
    'supportsUntaggedGroupToggle': supportsUntaggedGroupToggle,
    'supportsDiscovery': supportsDiscovery,
    'directRuleScopes': directRuleScopes,
    'sharedSpaceRuleScopes': sharedSpaceRuleScopes,
    'sharedActorRuleScopes': sharedActorRuleScopes,
    'manualEntryHint': manualEntryHint,
    'sharedModes': sharedModes,
    'requireSharedActor': requireSharedActor,
    'mentionOnly': mentionOnly,
  };
}

class MessagingAccessTarget {
  const MessagingAccessTarget({
    required this.source,
    required this.bucket,
    required this.scope,
    required this.value,
    required this.label,
    required this.subtitle,
    this.spaceScope,
    this.spaceValue,
    this.spaceLabel,
  });

  factory MessagingAccessTarget.fromJson(Map<String, dynamic> json) {
    final nestedRule = _jsonMap(json['rule']);
    final scope =
        json['scope']?.toString() ?? nestedRule['scope']?.toString() ?? 'chat';
    final value =
        json['value']?.toString() ?? nestedRule['value']?.toString() ?? '';
    return MessagingAccessTarget(
      source: json['source']?.toString() ?? 'manual',
      bucket: json['bucket']?.toString() ?? 'sharedSpaceRules',
      scope: scope,
      value: value,
      label:
          nestedRule['label']?.toString().ifEmpty(
            json['label']?.toString() ?? value,
          ) ??
          json['label']?.toString().ifEmpty(value) ??
          value,
      subtitle:
          json['subtitle']?.toString() ??
          nestedRule['spaceLabel']?.toString() ??
          '',
      spaceScope:
          json['spaceScope']?.toString() ??
          nestedRule['spaceScope']?.toString(),
      spaceValue:
          json['spaceValue']?.toString() ??
          nestedRule['spaceValue']?.toString(),
      spaceLabel:
          json['spaceLabel']?.toString() ??
          nestedRule['spaceLabel']?.toString(),
    );
  }

  final String source;
  final String bucket;
  final String scope;
  final String value;
  final String label;
  final String subtitle;
  final String? spaceScope;
  final String? spaceValue;
  final String? spaceLabel;

  MessagingAccessRule get asRule => MessagingAccessRule(
    scope: scope,
    value: value,
    label: label,
    spaceScope: spaceScope,
    spaceValue: spaceValue,
    spaceLabel: spaceLabel,
  );

  String get id =>
      '$bucket:$scope:$value:${spaceScope ?? ''}:${spaceValue ?? ''}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source,
    'bucket': bucket,
    'scope': scope,
    'value': value,
    'label': label,
    'subtitle': subtitle,
    if (spaceScope != null && spaceScope!.trim().isNotEmpty)
      'spaceScope': spaceScope,
    if (spaceValue != null && spaceValue!.trim().isNotEmpty)
      'spaceValue': spaceValue,
    if (spaceLabel != null && spaceLabel!.trim().isNotEmpty)
      'spaceLabel': spaceLabel,
  };
}

class MessagingAccessCatalog {
  const MessagingAccessCatalog({
    required this.platform,
    required this.policy,
    required this.capabilities,
    required this.discoveredTargets,
    required this.suggestedTargets,
    required this.summary,
  });

  factory MessagingAccessCatalog.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    List<MessagingAccessTarget> parseTargets(dynamic raw) {
      if (raw is! List) return const <MessagingAccessTarget>[];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                MessagingAccessTarget.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.value.isNotEmpty)
          .toList(growable: false);
    }

    return MessagingAccessCatalog(
      platform: platform,
      policy: MessagingAccessPolicy.fromJson(_jsonMap(json['policy'])),
      capabilities: MessagingAccessCapabilities.fromJson(
        _jsonMap(json['capabilities']),
      ),
      discoveredTargets: parseTargets(json['discoveredTargets']),
      suggestedTargets: parseTargets(json['suggestedTargets']),
      summary: json['summary']?.toString() ?? appStrings.whoCanMessage,
    );
  }

  factory MessagingAccessCatalog.empty(String platform) {
    return MessagingAccessCatalog(
      platform: platform,
      policy: const MessagingAccessPolicy.defaults(),
      capabilities: const MessagingAccessCapabilities(),
      discoveredTargets: const <MessagingAccessTarget>[],
      suggestedTargets: const <MessagingAccessTarget>[],
      summary: appStrings.whoCanMessage,
    );
  }

  final String platform;
  final MessagingAccessPolicy policy;
  final MessagingAccessCapabilities capabilities;
  final List<MessagingAccessTarget> discoveredTargets;
  final List<MessagingAccessTarget> suggestedTargets;
  final String summary;

  String get compactAccessLabel {
    final direct = policy.directPolicy;
    final shared = capabilities.supportsSharedPolicy
        ? policy.sharedPolicy
        : direct;
    if (direct == 'disabled' &&
        (!capabilities.supportsSharedPolicy || shared == 'disabled')) {
      return appStrings.noOneCanMessage;
    }
    if (direct == 'open' &&
        (!capabilities.supportsSharedPolicy || shared == 'open')) {
      return appStrings.openToAnyone;
    }
    if (direct == 'allowlist' &&
        (!capabilities.supportsSharedPolicy || shared == 'allowlist')) {
      return policy.totalRuleCount == 0
          ? appStrings.addWhoCanMessage
          : appStrings.approvedPeopleOnly;
    }
    return appStrings.customAccess;
  }

  String accessHeadline({String? agentName}) {
    final name = messagingSubjectName(agentName);
    if (!capabilities.supportsSharedPolicy) {
      return appStrings.privateChatsArg1(messagingAccessModeLabel(policy.directPolicy).toLowerCase());
    }
    if (!capabilities.supportsDirectPolicy) {
      return appStrings.groupsArg1(messagingAccessModeLabel(policy.sharedPolicy).toLowerCase());
    }
    final sameMode = policy.directPolicy == policy.sharedPolicy;
    if (sameMode) {
      switch (policy.directPolicy) {
        case 'open':
          return appStrings.anyoneOnThisPlatformCanMessage(name);
        case 'disabled':
          return appStrings.arg1WillNotReplyOnThis(name);
        default:
          return policy.totalRuleCount == 0
              ? appStrings.addThePeopleAndGroupsArg1Should(name)
              : appStrings.arg1OnlyTalksToPeopleAnd(name);
      }
    }
    return appStrings.privateChatsArg1GroupsArg2(messagingAccessModeLabel(policy.directPolicy).toLowerCase(), messagingAccessModeLabel(policy.sharedPolicy).toLowerCase());
  }

  String accessHint({String? agentName}) {
    final name = messagingSubjectName(agentName);
    if (policy.directPolicy == 'allowlist' ||
        (capabilities.supportsSharedPolicy &&
            policy.sharedPolicy == 'allowlist')) {
      return appStrings.whenYouChooseApprovedOnlyAdd;
    }
    if (policy.directPolicy == 'open' &&
        (!capabilities.supportsSharedPolicy || policy.sharedPolicy == 'open')) {
      return appStrings.anyoneWhoCanReachThisAccount(name);
    }
    return appStrings.chooseWhoCanReachArg1Then(name);
  }

  List<String> get accessDetailChips {
    final details = <String>[];
    if (capabilities.supportsDirectPolicy) {
      details.add(
        appStrings.privateChatsArg1(messagingAccessModeLabel(policy.directPolicy)),
      );
    }
    if (capabilities.supportsSharedPolicy) {
      details.add(appStrings.groupsArg1(messagingAccessModeLabel(policy.sharedPolicy)));
      if (capabilities.supportsUntaggedGroupToggle) {
        if (!policy.defaultAllowUntaggedInShared) {
          details.add(appStrings.repliesWhenTagged);
        } else {
          final taggedOnly = policy.sharedParticipationRules
              .where((rule) => !rule.allowUntagged)
              .length;
          details.add(
            taggedOnly == 0
                ? appStrings.joinsGroupConversations
                : appStrings.arg1GroupsTaggedOnly(taggedOnly),
          );
        }
      }
    }
    if (policy.totalRuleCount > 0) {
      details.add(
        policy.totalRuleCount == 1
            ? appStrings.label1PersonOrGroupAdded
            : appStrings.arg1PeopleOrGroupsAdded(policy.totalRuleCount),
      );
    }
    return details;
  }
}

class BlockedSenderNotice {
  const BlockedSenderNotice({
    required this.id,
    required this.platform,
    required this.chatId,
    required this.sender,
    required this.senderName,
    required this.meta,
    required this.suggestions,
  });

  factory BlockedSenderNotice.fromSocket(Map<String, dynamic> json) {
    final platform = json['platform']?.toString() ?? 'web';
    final sender = json['sender']?.toString();
    final senderName = json['senderName']?.toString();
    final chatId = json['chatId']?.toString();
    final meta = (json['meta']?.toString() ?? '').trim();
    final suggestionsRaw = json['suggestions'];
    final suggestions = suggestionsRaw is List
        ? suggestionsRaw
              .whereType<Map>()
              .map(
                (item) => QuickAllowSuggestion.fromJson(
                  platform,
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.rule.value.isNotEmpty)
              .toList()
        : const <QuickAllowSuggestion>[];

    return BlockedSenderNotice(
      id: '$platform:${chatId ?? ''}:${sender ?? ''}',
      platform: platform,
      chatId: chatId,
      sender: sender,
      senderName: senderName,
      meta: meta,
      suggestions: suggestions,
    );
  }

  final String id;
  final String platform;
  final String? chatId;
  final String? sender;
  final String? senderName;
  final String meta;
  final List<QuickAllowSuggestion> suggestions;

  String get senderLabel =>
      senderName?.ifEmpty(sender ?? platform.toUpperCase()) ??
      sender?.ifEmpty(platform.toUpperCase()) ??
      platform.toUpperCase();
}

class QuickAllowSuggestion {
  const QuickAllowSuggestion({
    required this.label,
    required this.bucket,
    required this.rule,
  });

  factory QuickAllowSuggestion.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    final ruleJson = _jsonMap(json['rule']);
    final prefixedId = json['prefixedId']?.toString().trim() ?? '';
    final MessagingAccessRule? parsedRule = ruleJson.isNotEmpty
        ? MessagingAccessRule.fromJson(ruleJson)
        : _ruleFromPrefixedEntry(platform, prefixedId);
    if (parsedRule == null) {
      return QuickAllowSuggestion(
        label: appStrings.allowSender,
        bucket: 'sharedActorRules',
        rule: MessagingAccessRule(scope: 'chat', value: ''),
      );
    }
    return QuickAllowSuggestion(
      label:
          json['label']?.toString().ifEmpty(appStrings.allowSender) ?? appStrings.allowSender,
      bucket:
          json['bucket']?.toString().ifEmpty('sharedActorRules') ??
          'sharedActorRules',
      rule: parsedRule,
    );
  }

  final String label;
  final String bucket;
  final MessagingAccessRule rule;
}

MessagingAccessRule? _ruleFromPrefixedEntry(String platform, String entry) {
  final normalized = _normalizeSuggestedWhitelistEntry(platform, entry);
  if (normalized.isEmpty) return null;
  if (platform == 'whatsapp') {
    return MessagingAccessRule(scope: 'phone_number', value: normalized);
  }
  final match = RegExp(r'^([a-z_]+):(.*)$').firstMatch(normalized);
  if (match != null) {
    final scope = match.group(1) ?? '';
    final value = match.group(2) ?? '';
    if (scope.isEmpty || value.isEmpty) return null;
    return MessagingAccessRule(
      scope: scope == 'guild' ? 'server' : scope,
      value: value,
    );
  }
  return MessagingAccessRule(scope: 'chat', value: normalized);
}

class MemoryTransferImportResult {
  const MemoryTransferImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.coreUpdatedCount,
    required this.behaviorNotesUpdated,
    required this.warnings,
  });

  factory MemoryTransferImportResult.fromJson(Map<dynamic, dynamic> json) {
    return MemoryTransferImportResult(
      importedCount: _asInt(json['importedCount']),
      skippedCount: _asInt(json['skippedCount']),
      coreUpdatedCount: _asInt(json['coreUpdatedCount']),
      behaviorNotesUpdated: json['behaviorNotesUpdated'] == true,
      warnings: _jsonStringList(json['warnings']),
    );
  }

  final int importedCount;
  final int skippedCount;
  final int coreUpdatedCount;
  final bool behaviorNotesUpdated;
  final List<String> warnings;
}

class VoiceTimelineItem {
  const VoiceTimelineItem({
    required this.id,
    required this.role,
    required this.content,
    required this.isFinal,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final bool isFinal;
  final DateTime createdAt;

  VoiceTimelineItem copyWith({String? content, bool? isFinal}) {
    return VoiceTimelineItem(
      id: id,
      role: role,
      content: content ?? this.content,
      isFinal: isFinal ?? this.isFinal,
      createdAt: createdAt,
    );
  }
}

class VoiceAssistantLiveState {
  VoiceAssistantLiveState({
    this.sessionId = '',
    this.inputMode = 'hands_free',
    this.inputSampleRate = 24000,
    this.outputSampleRate = 24000,
    this.provider = '',
    this.model = '',
    this.voice = '',
    this.activeRunId = '',
    this.activeTaskRequest = '',
    this.transportState = 'connected',
    this.state = 'idle',
    List<VoiceTimelineItem>? timeline,
    this.error,
  }) : timeline = timeline ?? const <VoiceTimelineItem>[];

  final String sessionId;
  final String inputMode;
  final int inputSampleRate;
  final int outputSampleRate;
  final String provider;
  final String model;
  final String voice;

  /// The background task the live model handed off, while it runs.
  final String activeRunId;
  final String activeTaskRequest;
  final String transportState;

  /// Server-reported conversation state: connecting, listening, speaking,
  /// reconnecting, closed, or idle before a session exists.
  final String state;
  final List<VoiceTimelineItem> timeline;
  final String? error;

  bool get hasActiveSession => sessionId.trim().isNotEmpty;
  bool get isHandsFree => inputMode == 'hands_free';
  bool get isSpeaking => state == 'speaking';
  bool get isConnecting => state == 'connecting' || state == 'reconnecting';
  bool get hasActiveTask => activeRunId.trim().isNotEmpty;

  /// A handed-off task is still running and the assistant is not speaking,
  /// so the call would otherwise sit in silence.
  bool get isWorkingSilently =>
      hasActiveSession &&
      hasActiveTask &&
      !isSpeaking &&
      !isConnecting &&
      transportState == 'connected' &&
      (error == null || error!.trim().isEmpty);

  String _latest(String role, {bool? finalOnly}) {
    for (final item in timeline.reversed) {
      if (item.role != role) continue;
      if (finalOnly != null && item.isFinal != finalOnly) continue;
      if (item.content.trim().isNotEmpty) return item.content;
    }
    return '';
  }

  String get partialTranscript => _latest('user');
  String get finalTranscript => _latest('user', finalOnly: true);
  String get assistantText => _latest('assistant');

  VoiceAssistantLiveState copyWith({
    String? sessionId,
    String? inputMode,
    int? inputSampleRate,
    int? outputSampleRate,
    String? provider,
    String? model,
    String? voice,
    String? activeRunId,
    String? activeTaskRequest,
    String? transportState,
    String? state,
    List<VoiceTimelineItem>? timeline,
    String? error,
    bool clearError = false,
  }) {
    return VoiceAssistantLiveState(
      sessionId: sessionId ?? this.sessionId,
      inputMode: inputMode ?? this.inputMode,
      inputSampleRate: inputSampleRate ?? this.inputSampleRate,
      outputSampleRate: outputSampleRate ?? this.outputSampleRate,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      activeRunId: activeRunId ?? this.activeRunId,
      activeTaskRequest: activeTaskRequest ?? this.activeTaskRequest,
      transportState: transportState ?? this.transportState,
      state: state ?? this.state,
      timeline: timeline ?? this.timeline,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RunDetailSnapshot {
  const RunDetailSnapshot({
    required this.run,
    required this.steps,
    required this.events,
    required this.response,
  });

  factory RunDetailSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return RunDetailSnapshot(
      run: RunSummary.fromJson(_jsonMap(json['run'])),
      steps: _jsonMapList(
        json['steps'],
        fallbackToMapValues: true,
      ).map(RunStepItem.fromJson).toList(),
      events: _jsonMapList(
        json['events'],
        fallbackToMapValues: true,
      ).map(RunEventItem.fromJson).toList(),
      response: json['response']?.toString() ?? '',
    );
  }

  final RunSummary run;
  final List<RunStepItem> steps;
  final List<RunEventItem> events;
  final String response;

  int get completedTools => steps
      .where((step) => step.toolName.isNotEmpty && step.status == 'completed')
      .length;

  int get failedTools => steps.where((step) => step.status == 'failed').length;

  int get helperCount => steps.where((step) {
    final label = appStrings.arg1Arg23(step.type, step.toolName).toLowerCase();
    return label.contains('subagent') || label.contains('helper');
  }).length;

  int get webStepCount => steps.where((step) => step.isWebRelated).length;

  int get planningStepCount =>
      steps.where((step) => step.isPlanningRelated).length;
}

class RunPromptTurn {
  const RunPromptTurn({
    required this.requestId,
    required this.phase,
    required this.iteration,
    required this.provider,
    required this.model,
    required this.messageCount,
    required this.toolCount,
    required this.characters,
    required this.createdAt,
  });

  factory RunPromptTurn.fromJson(Map<dynamic, dynamic> json) {
    return RunPromptTurn(
      requestId: json['requestId']?.toString() ?? '',
      phase: json['phase']?.toString() ?? 'model_turn',
      iteration: _asInt(json['iteration']),
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      messageCount: _asInt(json['messageCount']),
      toolCount: _asInt(json['toolCount']),
      characters: _asInt(json['characters']),
      createdAt: _parseOptionalTimestamp(json['createdAt']?.toString()),
    );
  }

  final String requestId;
  final String phase;
  final int iteration;
  final String provider;
  final String model;
  final int messageCount;
  final int toolCount;
  final int characters;
  final DateTime? createdAt;

  String get label {
    final phaseLabel = _titleCase(phase.replaceAll('_', ' '));
    return iteration > 0 ? '$phaseLabel $iteration' : phaseLabel;
  }
}

class RunPromptSection {
  const RunPromptSection({
    required this.role,
    required this.label,
    required this.text,
    required this.characters,
  });

  factory RunPromptSection.fromJson(Map<dynamic, dynamic> json) {
    return RunPromptSection(
      role: json['role']?.toString() ?? 'unknown',
      label: json['label']?.toString() ?? 'Section',
      text: json['text']?.toString() ?? '',
      characters: _asInt(json['characters']),
    );
  }

  final String role;
  final String label;
  final String text;
  final int characters;
}

class RunPromptSnapshot {
  const RunPromptSnapshot({
    required this.requestId,
    required this.sections,
    required this.toolNames,
  });

  factory RunPromptSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return RunPromptSnapshot(
      requestId: json['requestId']?.toString() ?? '',
      sections: _jsonMapList(
        json['sections'],
      ).map(RunPromptSection.fromJson).toList(),
      toolNames: _jsonMapList(json['tools'])
          .map((tool) => tool['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }

  final String requestId;
  final List<RunPromptSection> sections;
  final List<String> toolNames;

  int get characters =>
      sections.fold(0, (total, section) => total + section.characters);

  String get plainText => sections
      .map(
        (section) => appStrings.arg1Arg2Arg310(section.label, section.role, section.text),
      )
      .join('\n\n');
}

class ArtifactContractItem {
  const ArtifactContractItem({
    required this.kind,
    required this.path,
    required this.uri,
    required this.label,
    required this.mimeType,
    required this.size,
  });

  factory ArtifactContractItem.fromJson(Map<dynamic, dynamic> json) {
    return ArtifactContractItem(
      kind: json['kind']?.toString() ?? 'artifact',
      path: json['path']?.toString() ?? '',
      uri: json['uri']?.toString() ?? json['url']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      mimeType:
          json['mimeType']?.toString() ?? json['mime_type']?.toString() ?? '',
      size: _asInt(json['size'] ?? json['byte_size']),
    );
  }

  final String kind;
  final String path;
  final String uri;
  final String label;
  final String mimeType;
  final int size;

  String get displayLabel => label.ifEmpty(path.ifEmpty(uri.ifEmpty(kind)));
}

class RunEventItem {
  const RunEventItem({
    required this.id,
    required this.eventType,
    required this.sequenceIndex,
    required this.requestId,
    required this.stepId,
    required this.payload,
    required this.createdAt,
  });

  factory RunEventItem.fromJson(Map<dynamic, dynamic> json) {
    return RunEventItem(
      id: _asInt(json['id']),
      eventType:
          json['eventType']?.toString().ifEmpty(
            json['event_type']?.toString() ?? 'event',
          ) ??
          'event',
      sequenceIndex: _asInt(json['sequenceIndex'] ?? json['sequence_index']),
      requestId:
          json['requestId']?.toString() ?? json['request_id']?.toString(),
      stepId: json['stepId']?.toString() ?? json['step_id']?.toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : (json['payload_json'] is Map
                ? Map<String, dynamic>.from(json['payload_json'] as Map)
                : const <String, dynamic>{}),
      createdAt: _parseOptionalTimestamp(
        json['createdAt']?.toString() ?? json['created_at']?.toString(),
      ),
    );
  }

  final int id;
  final String eventType;
  final int sequenceIndex;
  final String? requestId;
  final String? stepId;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  String get title {
    switch (eventType) {
      case 'deliverable_workflow_selected':
        return appStrings.deliverableSelected;
      case 'deliverable_execution_started':
        return appStrings.deliverableExecutionStarted;
      case 'deliverable_artifact_produced':
        return appStrings.deliverableArtifactProduced;
      case 'deliverable_validation_started':
        return appStrings.deliverableValidationStarted;
      case 'deliverable_validation_failed':
        return appStrings.deliverableValidationFailed;
      case 'deliverable_completed':
        return appStrings.deliverableCompleted;
      case 'run_started':
        return appStrings.runStarted;
      case 'memory_injected':
        return appStrings.memoryInjected;
      case 'model_turn_started':
        return appStrings.modelTurnStarted;
      case 'model_turn_completed':
        return appStrings.modelTurnCompleted;
      case 'tool_started':
        return appStrings.toolStarted;
      case 'tool_completed':
        return appStrings.toolCompleted;
      case 'tool_failed':
        return appStrings.toolFailed;
      case 'run_completed':
        return appStrings.runCompleted;
      case 'run_failed':
        return appStrings.runFailed;
      case 'run_stopped':
        return appStrings.runStopped;
      default:
        return _titleCase(eventType.replaceAll('_', ' '));
    }
  }

  String get detail {
    final toolName = payload['toolName']?.toString() ?? '';
    if (toolName.trim().isNotEmpty) return toolName;
    final preview =
        payload['contentPreview']?.toString() ??
        payload['recallPreview']?.toString() ??
        '';
    if (preview.trim().isNotEmpty) return preview;
    final error = payload['error']?.toString() ?? '';
    if (error.trim().isNotEmpty) return error;
    final artifactLabel = payload['artifact'] is Map
        ? (payload['artifact']['label']?.toString() ??
              payload['artifact']['path']?.toString() ??
              payload['artifact']['uri']?.toString() ??
              '')
        : '';
    if (artifactLabel.trim().isNotEmpty) return artifactLabel;
    final titleValue = payload['title']?.toString() ?? '';
    return titleValue;
  }

  String get createdAtLabel =>
      createdAt == null ? '' : _formatTimestamp(createdAt!);

  bool get isFailure => eventType == 'tool_failed' || eventType == 'run_failed';
}

class RunStepItem {
  const RunStepItem({
    required this.id,
    required this.index,
    required this.type,
    required this.description,
    required this.status,
    required this.toolName,
    required this.toolInput,
    required this.result,
    required this.error,
    required this.tokensUsed,
    required this.startedAt,
    required this.completedAt,
  });

  factory RunStepItem.fromJson(Map<dynamic, dynamic> json) {
    return RunStepItem(
      id: json['id']?.toString() ?? '',
      index: _asInt(json['step_index']),
      type: json['type']?.toString().ifEmpty('step') ?? 'step',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString().ifEmpty('pending') ?? 'pending',
      toolName: json['tool_name']?.toString() ?? '',
      toolInput: json['tool_input']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
      tokensUsed: _asInt(json['tokens_used']),
      startedAt: _parseOptionalTimestamp(json['started_at']?.toString()),
      completedAt: _parseOptionalTimestamp(json['completed_at']?.toString()),
    );
  }

  final String id;
  final int index;
  final String type;
  final String description;
  final String status;
  final String toolName;
  final String toolInput;
  final String result;
  final String error;
  final int tokensUsed;
  final DateTime? startedAt;
  final DateTime? completedAt;

  int get displayIndex => index + 1;

  String get label => toolName.ifEmpty(type.replaceAll('_', ' '));

  String get typeLabel => _titleCase(type.replaceAll('_', ' '));

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get inputSummary =>
      _summarizeToolArgs(_decodeMaybeJson(toolInput)).ifEmpty('');

  String? get startedAtLabel =>
      startedAt == null ? null : _formatTimestamp(startedAt!);

  Duration? get duration => startedAt == null || completedAt == null
      ? null
      : completedAt!.difference(startedAt!);

  String? get durationLabel =>
      duration == null ? null : _formatElapsed(duration!);

  String get summary {
    final resultText = _summarizeToolResult(_decodeMaybeJson(result));
    if (error.trim().isNotEmpty) {
      return error;
    }
    if (resultText.trim().isNotEmpty) {
      return resultText;
    }
    return description.ifEmpty(appStrings.noDetailsCaptured);
  }

  String get compactSummary => _condenseRunText(summary, maxLength: 140);

  String get laneLabel {
    if (isPlanningRelated) {
      return appStrings.planning;
    }
    if (isHelperRelated) {
      return appStrings.helper;
    }
    if (isWebRelated) {
      return appStrings.web;
    }
    if (type == 'verification') {
      return appStrings.verification;
    }
    return appStrings.execution;
  }

  bool get isPlanningRelated =>
      type == 'analysis' || type == 'planning' || toolName == 'analysis';

  bool get isHelperRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('subagent') || label.contains('helper');
  }

  bool get isBrowserRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('browser') ||
        label.contains('page') ||
        label.contains('screenshot');
  }

  bool get isMessagingRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('message') ||
        label.contains('telegram') ||
        label.contains('discord') ||
        label.contains('whatsapp') ||
        label.contains('slack');
  }

  bool get isWebRelated => isBrowserRelated || isMessagingRelated;

  IconData get laneIcon {
    if (isPlanningRelated) {
      return Icons.route_outlined;
    }
    if (isHelperRelated) {
      return Icons.account_tree_outlined;
    }
    if (isBrowserRelated) {
      return Icons.language_outlined;
    }
    if (isMessagingRelated) {
      return Icons.chat_bubble_outline;
    }
    if (type == 'verification') {
      return Icons.verified_outlined;
    }
    if (status == 'failed') {
      return Icons.error_outline;
    }
    return Icons.build_outlined;
  }

  Color get statusColor {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      case 'running':
        return _info;
      default:
        return _textSecondary;
    }
  }
}

String _condenseRunText(String value, {int maxLength = 160}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1).trimRight()}…';
}

dynamic _decodeMaybeJson(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Map || value is List) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      return jsonDecode(value);
    } catch (_) {}
  }
  return value;
}

Map<String, dynamic> _decodeJsonMap(
  String? value, {
  Map<String, dynamic> fallback = const <String, dynamic>{},
}) {
  final decoded = _decodeMaybeJson(value);
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return fallback;
}

class ChatEntry {
  const ChatEntry({
    required this.id,
    required this.role,
    required this.content,
    required this.platform,
    required this.createdAt,
    this.runId,
    this.senderName,
    this.metadata = const <String, dynamic>{},
    this.toolCalls = const <Map<String, dynamic>>[],
    this.transient = false,
    this.typing = false,
  });

  factory ChatEntry.fromJson(Map<dynamic, dynamic> json) {
    return ChatEntry(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'web',
      runId: json['run_id']?.toString(),
      senderName: json['sender_name']?.toString(),
      metadata: _jsonMap(_decodeMaybeJson(json['metadata'])),
      toolCalls: _jsonMapList(
        _decodeMaybeJson(json['tool_calls']),
        fallbackToMapValues: true,
      ),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final String id;
  final String role;
  final String content;
  final String platform;
  final String? runId;
  final String? senderName;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>> toolCalls;
  final DateTime createdAt;
  final bool transient;
  final bool typing;

  String get createdAtLabel => _formatTimestamp(createdAt);

  String? get platformTag {
    if (platform == 'live') {
      return 'LIVE';
    }
    if (platform != 'web' && platform != 'flutter' && platform.isNotEmpty) {
      return platform.toUpperCase();
    }
    return null;
  }

  ChatRichPayload? get richPayload {
    final schema = metadata['schema'];
    if (schema is! Map) return null;
    final type = schema['type']?.toString() ?? '';
    if (type != 'quick_reply' && type != 'list_picker') return null;
    final optList = schema['options'];
    if (optList is! List) return null;
    final options = optList
        .whereType<Map>()
        .map(
          (item) => ChatPayloadOption(
            label: item['label']?.toString() ?? '',
            value: item['value']?.toString() ?? '',
          ),
        )
        .where((o) => o.label.isNotEmpty)
        .toList(growable: false);
    if (options.isEmpty) return null;
    return ChatRichPayload(type: type, options: options);
  }
}

class SharedChatAttachment {
  const SharedChatAttachment({
    required this.uri,
    required this.name,
    required this.mimeType,
    this.sizeBytes,
    this.source = 'share_intent',
  });

  factory SharedChatAttachment.fromJson(Map<dynamic, dynamic> json) {
    return SharedChatAttachment(
      uri: json['uri']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Attachment',
      mimeType:
          json['mimeType']?.toString().ifEmpty('application/octet-stream') ??
          'application/octet-stream',
      sizeBytes: json['sizeBytes'] is num
          ? (json['sizeBytes'] as num).toInt()
          : null,
      source:
          json['source']?.toString().ifEmpty('share_intent') ?? 'share_intent',
    );
  }

  final String uri;
  final String name;
  final String mimeType;
  final int? sizeBytes;
  final String source;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uri': uri,
      'name': name,
      'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      'source': source,
    };
  }

  bool get isValid => uri.trim().isNotEmpty;
}

class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.description,
    required this.responsibilities,
    required this.instructions,
    required this.status,
    required this.isDefault,
    required this.canDelegate,
    required this.canBeDelegatedTo,
    required this.delegateTargets,
  });

  factory AgentProfile.fromJson(Map<dynamic, dynamic> json) {
    final displayName =
        json['displayName']?.toString().ifEmpty(appStrings.agent) ??
        json['display_name']?.toString().ifEmpty(appStrings.agent) ??
        appStrings.agent;
    return AgentProfile(
      id: json['id']?.toString() ?? '',
      slug:
          json['slug']?.toString().ifEmpty(
            displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
          ) ??
          'agent',
      displayName: displayName,
      description: json['description']?.toString() ?? '',
      responsibilities: json['responsibilities']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      status: json['status']?.toString().ifEmpty('active') ?? 'active',
      isDefault:
          json['isDefault'] == true ||
          json['isDefault'] == 1 ||
          json['is_default'] == true ||
          json['is_default'] == 1,
      canDelegate:
          json['canDelegate'] == true ||
          json['canDelegate'] == 1 ||
          json['can_delegate'] == true ||
          json['can_delegate'] == 1,
      canBeDelegatedTo:
          json['canBeDelegatedTo'] != false &&
          json['canBeDelegatedTo'] != 0 &&
          json['can_be_delegated_to'] != false &&
          json['can_be_delegated_to'] != 0,
      delegateTargets: _jsonStringList(
        json['delegateTargets'] ?? json['delegate_targets'],
        fallbackToMapValues: true,
      ),
    );
  }

  final String id;
  final String slug;
  final String displayName;
  final String description;
  final String responsibilities;
  final String instructions;
  final String status;
  final bool isDefault;
  final bool canDelegate;
  final bool canBeDelegatedTo;
  final List<String> delegateTargets;

  bool get isMain => slug == 'main';
  bool get isArchived => status == 'archived';
  String get label => isDefault ? appStrings.arg1Default2(displayName) : displayName;
  bool get delegatesToAnyEligibleAgent =>
      canDelegate && delegateTargets.isEmpty;
}

class ModelMeta {
  const ModelMeta({
    required this.id,
    required this.modelId,
    required this.label,
    required this.provider,
    required this.purpose,
    this.available = true,
    this.providerStatus = '',
    this.providerStatusLabel = '',
    this.priceTier,
    this.isByok = false,
    this.byokLabel = '',
  });

  factory ModelMeta.fromJson(Map<dynamic, dynamic> json) {
    return ModelMeta(
      id: json['id']?.toString() ?? '',
      modelId: json['modelId']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      available: json['available'] != false,
      providerStatus: json['providerStatus']?.toString() ?? '',
      providerStatusLabel: json['providerStatusLabel']?.toString() ?? '',
      priceTier: json['priceTier']?.toString(),
      isByok: json['isByok'] == true,
      byokLabel: json['byokLabel']?.toString() ?? '',
    );
  }

  final String id;
  final String modelId;
  final String label;
  final String provider;
  final String purpose;
  final bool available;
  final String providerStatus;
  final String providerStatusLabel;

  /// Pricing tier: 'free' | 'cheap' | 'medium' | 'expensive' | null (unknown)
  final String? priceTier;

  /// True when this model runs on the current user's own (bring-your-own-key)
  /// provider credentials rather than the server's shared ones.
  final bool isByok;
  final String byokLabel;
}

class AiProviderMeta {
  const AiProviderMeta({
    required this.id,
    required this.label,
    required this.description,
    required this.enabled,
    required this.available,
    required this.supportsApiKey,
    required this.supportsBaseUrl,
    required this.defaultBaseUrl,
    required this.credentialConfigured,
    required this.baseUrl,
    required this.status,
    required this.statusLabel,
    required this.availabilityReason,
    required this.modelCount,
    required this.availableModelCount,
    this.authentication = 'api_key',
    this.requiresBaseUrl = false,
    this.isByok = false,
  });

  factory AiProviderMeta.fromJson(Map<dynamic, dynamic> json) {
    return AiProviderMeta(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] != false,
      available: json['available'] == true,
      supportsApiKey: json['supportsApiKey'] == true,
      supportsBaseUrl: json['supportsBaseUrl'] == true,
      defaultBaseUrl: json['defaultBaseUrl']?.toString() ?? '',
      credentialConfigured: json['credentialConfigured'] == true,
      baseUrl: json['baseUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? '',
      availabilityReason: json['availabilityReason']?.toString() ?? '',
      modelCount: _asInt(json['modelCount']),
      availableModelCount: _asInt(json['availableModelCount']),
      authentication: json['authentication']?.toString() ?? 'api_key',
      requiresBaseUrl: json['requiresBaseUrl'] == true,
      isByok: json['isByok'] == true,
    );
  }

  final String id;
  final String label;
  final String description;
  final bool enabled;
  final bool available;
  final bool supportsApiKey;
  final bool supportsBaseUrl;
  final String defaultBaseUrl;
  final bool credentialConfigured;
  final String baseUrl;
  final String status;
  final String statusLabel;
  final String availabilityReason;
  final int modelCount;
  final int availableModelCount;
  final String authentication;
  final bool requiresBaseUrl;
  final bool isByok;

  bool get usesApiKey => authentication == 'api_key' && supportsApiKey;
  bool get isLocal => authentication == 'local';
  bool get usesOAuth => authentication == 'oauth';

  IconData get icon {
    switch (id) {
      case 'openai':
      case 'chatgpt':
        return Icons.auto_awesome;
      case 'anthropic':
        return Icons.edit_note_outlined;
      case 'google':
        return Icons.multitrack_audio_outlined;
      case 'grok':
        return Icons.bolt_outlined;
      case 'ollama':
        return Icons.storage_outlined;
      case 'github-copilot':
        return Icons.code;
      case 'openai-codex':
        return Icons.psychology_outlined;
      default:
        return Icons.hub_outlined;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'ready':
      case 'healthy':
      case 'configured':
      case 'local':
        return _success;
      case 'offline':
        return _danger;
      case 'disabled':
        return _textSecondary;
      case 'needs_key':
      case 'needs_setup':
        return _warning;
      default:
        return _info;
    }
  }

  String get modelSummary {
    if (modelCount == 0) {
      return appStrings.noModelsDiscoveredYet;
    }
    if (availableModelCount == modelCount) {
      return appStrings.arg1ModelsReady(modelCount);
    }
    return appStrings.arg1OfArg2ModelsReady(availableModelCount, modelCount);
  }
}

class RunSummary {
  const RunSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.model,
    required this.triggerSource,
    required this.totalTokens,
    required this.createdAt,
    this.completedAt,
    this.error = '',
    this.metadata = const <String, dynamic>{},
  });

  factory RunSummary.fromJson(Map<dynamic, dynamic> json) {
    final metadata = _decodeJsonMap(
      json['metadata_json']?.toString(),
      fallback: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
    return RunSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      status: json['status']?.toString() ?? 'unknown',
      model: json['model']?.toString() ?? '',
      triggerSource: json['trigger_source']?.toString() ?? '',
      totalTokens: _asInt(json['total_tokens']),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      completedAt: _parseOptionalTimestamp(json['completed_at']?.toString()),
      error: json['error']?.toString() ?? '',
      metadata: metadata,
    );
  }

  final String id;
  final String title;
  final String status;
  final String model;
  final String triggerSource;
  final int totalTokens;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String error;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> get deliverable => metadata['deliverable'] is Map
      ? Map<String, dynamic>.from(metadata['deliverable'] as Map)
      : const <String, dynamic>{};

  String get deliverableType => deliverable['type']?.toString() ?? '';

  String get deliverableSummary => deliverable['summary']?.toString() ?? '';

  List<ArtifactContractItem> get deliverableArtifacts {
    final raw = deliverable['artifacts'];
    if (raw is! List) return const <ArtifactContractItem>[];
    return raw
        .whereType<Map>()
        .map(ArtifactContractItem.fromJson)
        .toList(growable: false);
  }

  bool get isFailure => status == 'failed' || status == 'error';

  /// Still executing: counts toward the live section and ticks its elapsed time.
  bool get isActive =>
      status == 'running' || status == 'paused' || status == 'waiting_input';

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get totalTokensLabel => _formatNumber(totalTokens);

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get triggerLabel => triggerSource.ifEmpty('web');

  /// The server moved this chat run to the background so the chat stayed free.
  bool get ranInBackground => metadata['background'] is Map;

  String get sourceLabel => ranInBackground
      ? '$triggerLabel · ${appStrings.inBackground}'
      : triggerLabel;

  String get modelLabel => model.ifEmpty(appStrings.modelPending);

  Duration? get duration => completedAt?.difference(createdAt);

  String get durationLabel =>
      completedAt == null ? appStrings.inProgress : _formatElapsed(duration!);

  Color get statusColor {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
      case 'error':
        return _danger;
      case 'running':
        return _info;
      case 'paused':
      case 'waiting_input':
        return _warning;
      default:
        return _textSecondary;
    }
  }
}

class TokenUsageSnapshot {
  const TokenUsageSnapshot({
    required this.totalTokens,
    required this.totalRuns,
    required this.avgTokensPerRun,
    required this.last7DaysTokens,
    required this.last7DaysRuns,
    required this.cachedReadTokens,
    required this.cacheWriteTokens,
    required this.reasoningTokens,
    required this.modelCallCount,
    required this.cacheHitRatio,
    this.estimatedCostUsd,
  });

  factory TokenUsageSnapshot.fromJson(Map<dynamic, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    final modelUsage = json['modelUsage'] is Map
        ? Map<String, dynamic>.from(json['modelUsage'] as Map)
        : const <String, dynamic>{};
    return TokenUsageSnapshot(
      totalTokens: _asInt(totals['totalTokens']),
      totalRuns: _asInt(totals['totalRuns']),
      avgTokensPerRun: _asInt(totals['avgTokensPerRun']),
      last7DaysTokens: _asInt(totals['last7DaysTokens']),
      last7DaysRuns: _asInt(totals['last7DaysRuns']),
      cachedReadTokens: _asInt(modelUsage['cachedReadTokens']),
      cacheWriteTokens: _asInt(modelUsage['cacheWriteTokens']),
      reasoningTokens: _asInt(modelUsage['reasoningTokens']),
      modelCallCount: _asInt(modelUsage['callCount']),
      cacheHitRatio: (modelUsage['cacheHitRatio'] as num?)?.toDouble() ?? 0,
      estimatedCostUsd: (modelUsage['estimatedCostUsd'] as num?)?.toDouble(),
    );
  }

  final int totalTokens;
  final int totalRuns;
  final int avgTokensPerRun;
  final int last7DaysTokens;
  final int last7DaysRuns;
  final int cachedReadTokens;
  final int cacheWriteTokens;
  final int reasoningTokens;
  final int modelCallCount;
  final double cacheHitRatio;
  final double? estimatedCostUsd;

  String get totalTokensLabel => _formatNumber(totalTokens);
  String get totalRunsLabel => _formatNumber(totalRuns);
  String get avgTokensPerRunLabel => _formatNumber(avgTokensPerRun);
  String get last7DaysTokensLabel => _formatNumber(last7DaysTokens);
  String get last7DaysRunsLabel => _formatNumber(last7DaysRuns);
  String get cachedReadTokensLabel => _formatNumber(cachedReadTokens);
  String get cacheHitRatioLabel =>
      '${(cacheHitRatio * 100).toStringAsFixed(1)}%';
  String get estimatedCostLabel => estimatedCostUsd == null
      ? 'Unknown'
      : '\$${estimatedCostUsd!.toStringAsFixed(4)}';
}

class UpdateStatusSnapshot {
  const UpdateStatusSnapshot({
    this.state = 'idle',
    this.progress = 0,
    this.message = 'No update running',
    this.releaseChannel = 'stable',
    this.allowSelfUpdate = true,
    this.deploymentMode = 'self_hosted',
    this.targetBranch,
    this.versionBefore,
    this.versionAfter,
    this.backendVersion,
    this.installedVersion,
    this.runtimeValidationReady = true,
    this.runtimeValidationIssues = const <String>[],
    this.runtimeAcceleration,
    this.changelog = const <String>[],
    this.logs = const <String>[],
  });

  factory UpdateStatusSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return UpdateStatusSnapshot(
      state: json['state']?.toString() ?? 'idle',
      progress: _asInt(json['progress']).clamp(0, 100),
      message: json['message']?.toString() ?? appStrings.noUpdateRunning,
      releaseChannel: json['releaseChannel']?.toString() ?? 'stable',
      allowSelfUpdate: json['allowSelfUpdate'] != false,
      deploymentMode: json['deploymentMode']?.toString() ?? 'self_hosted',
      targetBranch: json['targetBranch']?.toString(),
      versionBefore: json['versionBefore']?.toString(),
      versionAfter: json['versionAfter']?.toString(),
      backendVersion: json['backendVersion']?.toString(),
      installedVersion:
          json['installedVersion']?.toString() ??
          json['packageVersion']?.toString(),
      runtimeValidationReady:
          _jsonMap(json['runtimeValidation'])['ready'] != false,
      runtimeValidationIssues: _jsonStringList(
        _jsonMap(json['runtimeValidation'])['issues'],
        fallbackToMapValues: true,
      ),
      runtimeAcceleration: _jsonMap(
        _jsonMap(json['runtimeValidation'])['vm'],
      )['acceleration']?.toString(),
      changelog: _jsonStringList(json['changelog'], fallbackToMapValues: true),
      logs: _jsonStringList(json['logs'], fallbackToMapValues: true),
    );
  }

  final String state;
  final int progress;
  final String message;
  final String releaseChannel;
  final bool allowSelfUpdate;
  final String deploymentMode;
  final String? targetBranch;
  final String? versionBefore;
  final String? versionAfter;
  final String? backendVersion;
  final String? installedVersion;
  final bool runtimeValidationReady;
  final List<String> runtimeValidationIssues;
  final String? runtimeAcceleration;
  final List<String> changelog;
  final List<String> logs;

  String get badgeLabel {
    switch (state) {
      case 'running':
        return appStrings.running;
      case 'completed':
        return appStrings.completed;
      case 'failed':
        return appStrings.failed;
      default:
        return appStrings.idle;
    }
  }

  Color get badgeColor {
    switch (state) {
      case 'running':
        return _info;
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      default:
        return _textSecondary;
    }
  }

  String get releaseChannelLabel =>
      releaseChannel.toLowerCase() == 'beta' ? 'Beta' : 'Stable';

  String get runtimeValidationLabel =>
      runtimeValidationReady ? appStrings.runtimeReady : appStrings.runtimeSetupRequired;

  Color get runtimeValidationColor =>
      runtimeValidationReady ? _success : _danger;

  String get versionLine {
    final before = versionBefore?.ifEmpty('—') ?? '—';
    final after = versionAfter?.ifEmpty('—') ?? '—';
    final updateVersion = after == '—' ? before : appStrings.arg1Arg211(before, after);
    final branch = targetBranch?.trim().isNotEmpty == true
        ? appStrings.branchArg1(targetBranch)
        : '';
    final installed = installedVersion == null
        ? ''
        : appStrings.installedArg1(installedVersion);
    final backend = backendVersion == null ? '' : appStrings.runtimeArg12(backendVersion);
    return appStrings.channelArg1Arg2UpdateVersionArg3(releaseChannelLabel, branch, updateVersion, installed, backend);
  }

  String get logsText =>
      logs.isEmpty ? appStrings.waitingForUpdateJobOutput : logs.join('\n');
}

class LogEntry {
  const LogEntry({
    required this.type,
    required this.message,
    required this.timestamp,
    this.source = 'server',
  });

  factory LogEntry.fromJson(Map<dynamic, dynamic> json) {
    return LogEntry(
      type: json['type']?.toString() ?? 'log',
      message: json['message']?.toString() ?? '',
      timestamp: _parseTimestamp(json['timestamp']?.toString()),
      source: json['source']?.toString().ifEmpty('server') ?? 'server',
    );
  }

  final String type;
  final String message;
  final DateTime timestamp;
  final String source;

  String get timeLabel => _formatTimeOnly(timestamp);

  String get clipboardLine => appStrings.arg1Arg2Arg311(timeLabel, source, message);

  Color get color {
    switch (type) {
      case 'error':
        return _danger;
      case 'warn':
        return _warning;
      case 'info':
        return _info;
      default:
        return _textPrimary;
    }
  }

  String get sourceLabel {
    switch (source) {
      case 'flutter':
        return 'Flutter';
      case 'server':
      default:
        return appStrings.server;
    }
  }
}

class SkillItem {
  const SkillItem({
    required this.name,
    required this.description,
    required this.enabled,
    required this.draft,
    required this.category,
    required this.source,
  });

  factory SkillItem.fromJson(Map<dynamic, dynamic> json) {
    return SkillItem(
      name: json['name']?.toString() ?? appStrings.skill,
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] != false,
      draft: json['draft'] == true,
      category: json['category']?.toString().ifEmpty('general') ?? 'general',
      source: json['source']?.toString().ifEmpty('local') ?? 'local',
    );
  }

  final String name;
  final String description;
  final bool enabled;
  final bool draft;
  final String category;
  final String source;
}

class StoreSkillItem {
  const StoreSkillItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.installed,
  });

  factory StoreSkillItem.fromJson(Map<dynamic, dynamic> json) {
    return StoreSkillItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? appStrings.skill,
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('general') ?? 'general',
      icon: json['icon']?.toString().ifEmpty('🧩') ?? '🧩',
      installed: json['installed'] == true,
    );
  }

  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final bool installed;
}

class OfficialIntegrationAppItem {
  const OfficialIntegrationAppItem({
    required this.id,
    required this.label,
    this.description,
    this.connection = const OfficialIntegrationConnectionStatus(
      status: 'not_connected',
      connected: false,
    ),
    this.accounts = const <OfficialIntegrationAccountItem>[],
    this.availableToolCount = 0,
    this.memoryCoverage = const OfficialIntegrationMemoryCoverage(),
  });

  factory OfficialIntegrationAppItem.fromJson(Map<dynamic, dynamic> json) {
    final accountsRaw = json['accounts'];
    return OfficialIntegrationAppItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'App',
      description: json['description']?.toString(),
      connection: OfficialIntegrationConnectionStatus.fromJson(
        _jsonMap(json['connection']),
      ),
      accounts: accountsRaw is List
          ? accountsRaw
                .whereType<Map<dynamic, dynamic>>()
                .map(OfficialIntegrationAccountItem.fromJson)
                .toList()
          : const <OfficialIntegrationAccountItem>[],
      availableToolCount: _asInt(json['availableToolCount']),
      memoryCoverage: OfficialIntegrationMemoryCoverage.fromJson(
        _jsonMap(json['memoryCoverage']),
      ),
    );
  }

  final String id;
  final String label;
  final String? description;
  final OfficialIntegrationConnectionStatus connection;
  final List<OfficialIntegrationAccountItem> accounts;
  final int availableToolCount;
  final OfficialIntegrationMemoryCoverage memoryCoverage;

  bool get isConnected => connection.connected;

  bool get hasExpiredAccounts =>
      accounts.any((account) => account.isExpired && !account.connected);

  String get effectiveStatus =>
      !isConnected && hasExpiredAccounts ? 'expired' : connection.status;

  String get statusLabel =>
      effectiveStatus == 'expired' ? 'Expired' : connection.statusLabel;
}

class OfficialIntegrationEnvStatus {
  const OfficialIntegrationEnvStatus({
    required this.configured,
    required this.missing,
    required this.summary,
    this.setupMode,
  });

  factory OfficialIntegrationEnvStatus.fromJson(Map<dynamic, dynamic> json) {
    final missingRaw = json['missing'];
    return OfficialIntegrationEnvStatus(
      configured: json['configured'] == true,
      missing: missingRaw is List
          ? missingRaw.map((item) => item.toString()).toList()
          : const <String>[],
      summary: json['summary']?.toString() ?? '',
      setupMode: json['setupMode']?.toString(),
    );
  }

  final bool configured;
  final List<String> missing;
  final String summary;
  final String? setupMode;
}

class OfficialIntegrationConnectionStatus {
  const OfficialIntegrationConnectionStatus({
    required this.status,
    required this.connected,
    this.accountEmail,
    this.lastConnectedAt,
    this.accountCount = 0,
    this.appCount = 0,
  });

  factory OfficialIntegrationConnectionStatus.fromJson(
    Map<dynamic, dynamic> json,
  ) {
    return OfficialIntegrationConnectionStatus(
      status: json['status']?.toString() ?? 'not_connected',
      connected: json['connected'] == true,
      accountEmail: json['accountEmail']?.toString(),
      lastConnectedAt: _parseOptionalTimestamp(
        json['lastConnectedAt']?.toString(),
      ),
      accountCount: _asInt(json['accountCount']),
      appCount: _asInt(json['appCount']),
    );
  }

  final String status;
  final bool connected;
  final String? accountEmail;
  final DateTime? lastConnectedAt;
  final int accountCount;
  final int appCount;

  String get statusLabel {
    switch (status) {
      case 'env_not_configured':
        return appStrings.setupRequired;
      case 'not_connected':
        return appStrings.notConnected2;
      case 'expired':
        return 'Expired';
      default:
        return _titleCase(status.replaceAll('_', ' '));
    }
  }
}

class OfficialIntegrationMemoryCoverage {
  const OfficialIntegrationMemoryCoverage({
    this.supported = false,
    this.contributesToMemory = false,
    this.contributesToTaskExecution = false,
    this.status = 'not_supported',
    this.dataDomains = const <String>[],
    this.documentCount = 0,
    this.lastRefreshAt,
    this.nextRefreshAt,
    this.error,
  });

  factory OfficialIntegrationMemoryCoverage.fromJson(
    Map<dynamic, dynamic> json,
  ) {
    final domainsRaw = json['dataDomains'];
    return OfficialIntegrationMemoryCoverage(
      supported: json['supported'] == true,
      contributesToMemory: json['contributesToMemory'] == true,
      contributesToTaskExecution: json['contributesToTaskExecution'] == true,
      status: json['status']?.toString() ?? 'not_supported',
      dataDomains: domainsRaw is List
          ? domainsRaw.map((item) => item.toString()).toList()
          : const <String>[],
      documentCount: _asInt(json['documentCount']),
      lastRefreshAt: _parseOptionalTimestamp(json['lastRefreshAt']?.toString()),
      nextRefreshAt: _parseOptionalTimestamp(json['nextRefreshAt']?.toString()),
      error: json['error']?.toString(),
    );
  }

  final bool supported;
  final bool contributesToMemory;
  final bool contributesToTaskExecution;
  final String status;
  final List<String> dataDomains;
  final int documentCount;
  final DateTime? lastRefreshAt;
  final DateTime? nextRefreshAt;
  final String? error;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));
}

class OfficialIntegrationAccountItem {
  const OfficialIntegrationAccountItem({
    required this.id,
    required this.status,
    required this.connected,
    this.accountEmail,
    this.lastConnectedAt,
    this.accessMode = 'read_write',
    this.supportsConnectionTest = false,
    this.memoryCoverage = const OfficialIntegrationMemoryCoverage(),
  });

  factory OfficialIntegrationAccountItem.fromJson(Map<dynamic, dynamic> json) {
    return OfficialIntegrationAccountItem(
      id: _asInt(json['id']),
      status: json['status']?.toString() ?? 'not_connected',
      connected: json['connected'] == true,
      accountEmail: json['accountEmail']?.toString(),
      lastConnectedAt: _parseOptionalTimestamp(
        json['lastConnectedAt']?.toString(),
      ),
      accessMode: json['accessMode']?.toString() ?? 'read_write',
      supportsConnectionTest: json['supportsConnectionTest'] == true,
      memoryCoverage: OfficialIntegrationMemoryCoverage.fromJson(
        _jsonMap(json['memoryCoverage']),
      ),
    );
  }

  final int id;
  final String status;
  final bool connected;
  final String? accountEmail;
  final DateTime? lastConnectedAt;
  final String accessMode;
  final bool supportsConnectionTest;
  final OfficialIntegrationMemoryCoverage memoryCoverage;

  bool get isExpired => status == 'expired';

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get accessModeLabel {
    switch (accessMode) {
      case 'read_only':
        return appStrings.readOnly;
      default:
        return appStrings.readWrite;
    }
  }
}

class OfficialIntegrationItem {
  const OfficialIntegrationItem({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.apps,
    required this.env,
    required this.connection,
    required this.availableToolCount,
    this.connectPrompt,
    this.supportsMultipleAccounts = true,
    this.connectionMethod = 'oauth',
    this.memoryCoverage = const OfficialIntegrationMemoryCoverage(),
  });

  factory OfficialIntegrationItem.fromJson(Map<dynamic, dynamic> json) {
    final appsRaw = json['apps'];
    return OfficialIntegrationItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? appStrings.integration,
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      apps: appsRaw is List
          ? appsRaw
                .whereType<Map<dynamic, dynamic>>()
                .map(OfficialIntegrationAppItem.fromJson)
                .toList()
          : const <OfficialIntegrationAppItem>[],
      env: OfficialIntegrationEnvStatus.fromJson(_jsonMap(json['env'])),
      connection: OfficialIntegrationConnectionStatus.fromJson(
        _jsonMap(json['connection']),
      ),
      availableToolCount: _asInt(json['availableToolCount']),
      connectPrompt: json['connectPrompt']?.toString(),
      supportsMultipleAccounts: json['supportsMultipleAccounts'] != false,
      connectionMethod: json['connectionMethod']?.toString() ?? 'oauth',
      memoryCoverage: OfficialIntegrationMemoryCoverage.fromJson(
        _jsonMap(json['memoryCoverage']),
      ),
    );
  }

  final String id;
  final String label;
  final String description;
  final String icon;
  final List<OfficialIntegrationAppItem> apps;
  final OfficialIntegrationEnvStatus env;
  final OfficialIntegrationConnectionStatus connection;
  final int availableToolCount;
  final String? connectPrompt;
  final bool supportsMultipleAccounts;
  final String connectionMethod;
  final OfficialIntegrationMemoryCoverage memoryCoverage;

  bool get isConnected => connection.connected;

  bool get hasExpiredAccounts => apps.any((app) => app.hasExpiredAccounts);

  String get effectiveStatus =>
      !isConnected && hasExpiredAccounts ? 'expired' : connection.status;

  String get statusLabel =>
      effectiveStatus == 'expired' ? 'Expired' : connection.statusLabel;
}

class SkillDocument {
  const SkillDocument({required this.name, required this.content});

  factory SkillDocument.fromJson(Map<dynamic, dynamic> json) {
    return SkillDocument(
      name: json['name']?.toString() ?? appStrings.skill,
      content: json['content']?.toString() ?? '',
    );
  }

  final String name;
  final String content;
}

class MemoryOverview {
  const MemoryOverview({
    this.assistantBehaviorNotes = '',
    this.dailyLogs = const <String>[],
    this.apiKeys = const <String, String>{},
    this.coreEntries = const <String, dynamic>{},
    this.stats = const MemoryStats(),
    this.recentKnowledgeChanges = const <KnowledgeChangeItem>[],
  });

  factory MemoryOverview.fromJson(Map<dynamic, dynamic> json) {
    final apiKeysRaw = json['apiKeys'];
    final coreRaw = json['coreMemory'];
    return MemoryOverview(
      assistantBehaviorNotes: json['assistantBehaviorNotes']?.toString() ?? '',
      dailyLogs: _jsonStringList(json['dailyLogs'], fallbackToMapValues: true),
      apiKeys: apiKeysRaw is Map
          ? Map<String, String>.from(
              apiKeysRaw.map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
            )
          : const <String, String>{},
      coreEntries: coreRaw is Map
          ? Map<String, dynamic>.from(coreRaw)
          : const <String, dynamic>{},
      stats: MemoryStats.fromJson(_jsonMap(json['stats'])),
      recentKnowledgeChanges: _jsonMapList(
        json['recentKnowledgeChanges'],
      ).map(KnowledgeChangeItem.fromJson).toList(),
    );
  }

  final String assistantBehaviorNotes;
  final List<String> dailyLogs;
  final Map<String, String> apiKeys;
  final Map<String, dynamic> coreEntries;
  final MemoryStats stats;
  final List<KnowledgeChangeItem> recentKnowledgeChanges;

  int get behaviorNotesLength => assistantBehaviorNotes.length;
  int get dailyLogCount => dailyLogs.length;
  int get apiKeyCount => apiKeys.length;
  int get coreCount => coreEntries.length;
}

class MemoryStats {
  const MemoryStats({
    this.total = 0,
    this.active = 0,
    this.archived = 0,
    this.facts = 0,
    this.entities = 0,
    this.knowledgeViews = 0,
    this.ingestionDocuments = 0,
    this.averageImportance = 0,
    this.averageConfidence = 0,
  });

  factory MemoryStats.fromJson(Map<dynamic, dynamic> json) {
    return MemoryStats(
      total: _asInt(json['total']),
      active: _asInt(json['active']),
      archived: _asInt(json['archived']),
      facts: _asInt(json['facts']),
      entities: _asInt(json['entities']),
      knowledgeViews: _asInt(json['knowledgeViews']),
      ingestionDocuments: _asInt(json['ingestionDocuments']),
      averageImportance: _asDouble(json['averageImportance']),
      averageConfidence: _asDouble(json['averageConfidence']),
    );
  }

  final int total;
  final int active;
  final int archived;
  final int facts;
  final int entities;
  final int knowledgeViews;
  final int ingestionDocuments;
  final double averageImportance;
  final double averageConfidence;
}

class MemoryEntity {
  const MemoryEntity({
    required this.id,
    required this.key,
    required this.name,
    required this.kind,
    required this.mentionCount,
    this.lastSeenAt,
  });

  factory MemoryEntity.fromJson(Map<dynamic, dynamic> json) {
    return MemoryEntity(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString().ifEmpty('concept') ?? 'concept',
      mentionCount: _asInt(json['mentionCount']),
      lastSeenAt: _parseOptionalTimestamp(json['lastSeenAt']?.toString()),
    );
  }

  final String id;
  final String key;
  final String name;
  final String kind;
  final int mentionCount;
  final DateTime? lastSeenAt;
}

class MemoryGraphEdge {
  const MemoryGraphEdge({
    required this.source,
    required this.target,
    required this.weight,
  });

  factory MemoryGraphEdge.fromJson(Map<dynamic, dynamic> json) {
    return MemoryGraphEdge(
      source: json['source']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      weight: _asInt(json['weight']),
    );
  }

  final String source;
  final String target;
  final int weight;
}

class MemoryGraph {
  const MemoryGraph({
    this.nodes = const <MemoryEntity>[],
    this.edges = const <MemoryGraphEdge>[],
  });

  factory MemoryGraph.fromJson(Map<dynamic, dynamic> json) {
    return MemoryGraph(
      nodes: _jsonMapList(json['nodes']).map(MemoryEntity.fromJson).toList(),
      edges: _jsonMapList(json['edges']).map(MemoryGraphEdge.fromJson).toList(),
    );
  }

  final List<MemoryEntity> nodes;
  final List<MemoryGraphEdge> edges;
}

class KnowledgeChangeItem {
  const KnowledgeChangeItem({
    required this.title,
    required this.kind,
    required this.summary,
  });

  factory KnowledgeChangeItem.fromJson(Map<dynamic, dynamic> json) {
    return KnowledgeChangeItem(
      title: json['title']?.toString().ifEmpty('Change') ?? 'Change',
      kind: json['kind']?.toString().ifEmpty('change') ?? 'change',
      summary: json['summary']?.toString() ?? '',
    );
  }

  final String title;
  final String kind;
  final String summary;
}

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
    this.summary = '',
    this.confidence = 0.7,
    this.entities = const <MemoryEntity>[],
    this.score,
  });

  factory MemoryItem.fromJson(Map<dynamic, dynamic> json) {
    return MemoryItem(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('memory') ?? 'memory',
      importance: _asInt(json['importance']),
      confidence: _asDouble(json['confidence'], fallback: 0.7),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      entities: _jsonMapList(
        json['entities'],
      ).map(MemoryEntity.fromJson).toList(),
      score: (() {
        final raw = json['score'];
        if (raw == null) return null;
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString());
      })(),
    );
  }

  final String id;
  final String content;
  final String summary;
  final String category;
  final int importance;
  final double confidence;
  final DateTime createdAt;
  final List<MemoryEntity> entities;
  final double? score;

  String get createdAtLabel => _formatTimestamp(createdAt);
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);
}

class ConversationItem {
  const ConversationItem({required this.title, required this.preview});

  factory ConversationItem.fromJson(Map<dynamic, dynamic> json) {
    final raw =
        json['summary']?.toString().ifEmpty(
          json['content']?.toString() ?? '',
        ) ??
        '';
    return ConversationItem(
      title:
          json['title']?.toString().ifEmpty(appStrings.conversation) ?? appStrings.conversation,
      preview: raw.ifEmpty(appStrings.noSummaryAvailable),
    );
  }

  final String title;
  final String preview;
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.agentId,
    required this.name,
    required this.triggerType,
    required this.triggerSummary,
    required this.triggerConfig,
    required this.taskConfig,
    required this.loopPaused,
    required this.nextRun,
    required this.prompt,
    required this.model,
    required this.enabled,
    required this.lastRun,
    required this.lastRunId,
    required this.lastRunStatus,
    required this.lastRunError,
    required this.averageRunSeconds,
  });

  factory TaskItem.fromJson(Map<dynamic, dynamic> json) {
    final legacyConfig = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    final taskConfig = {
      ...legacyConfig,
      ...(json['taskConfig'] is Map
          ? Map<String, dynamic>.from(json['taskConfig'] as Map)
          : const <String, dynamic>{}),
    };
    final triggerConfig = {
      ...(legacyConfig['triggerConfig'] is Map
          ? Map<String, dynamic>.from(legacyConfig['triggerConfig'] as Map)
          : const <String, dynamic>{}),
      ...(json['triggerConfig'] is Map
          ? Map<String, dynamic>.from(json['triggerConfig'] as Map)
          : const <String, dynamic>{}),
    };
    final triggerSummary = json['triggerSummary']?.toString() ?? '';
    final legacyLoopBudget = taskConfig['loopBudget'] is Map
        ? Map<String, dynamic>.from(taskConfig['loopBudget'] as Map)
        : const <String, dynamic>{};
    return TaskItem(
      id: _asInt(json['id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString() ?? 'Task',
      triggerType: json['triggerType']?.toString() ?? 'schedule',
      triggerSummary: triggerSummary.trim().isEmpty
          ? appStrings.taskTrigger
          : triggerSummary,
      triggerConfig: triggerConfig,
      taskConfig: taskConfig,
      loopPaused:
          json['loopPaused'] == true ||
          taskConfig['loopPaused'] == true ||
          taskConfig['loop_paused'] == true ||
          legacyLoopBudget['paused'] == true ||
          legacyLoopBudget['pause'] == true,
      nextRun: _parseOptionalTimestamp(json['nextRun']?.toString()),
      prompt:
          json['prompt']?.toString().ifEmpty(
            taskConfig['prompt']?.toString() ?? '',
          ) ??
          '',
      model:
          json['model']?.toString().ifEmpty(
            taskConfig['model']?.toString() ?? '',
          ) ??
          '',
      enabled: json['enabled'] != false,
      lastRun: _parseOptionalTimestamp(json['lastRun']?.toString()),
      lastRunId: json['lastRunId']?.toString() ?? '',
      lastRunStatus: json['lastRunStatus']?.toString() ?? '',
      lastRunError: json['lastRunError']?.toString() ?? '',
      averageRunSeconds: json['averageRunSeconds'] == null
          ? null
          : _asInt(json['averageRunSeconds']),
    );
  }

  final int id;
  final String? agentId;
  final String name;
  final String triggerType;
  final String triggerSummary;
  final Map<String, dynamic> triggerConfig;
  final Map<String, dynamic> taskConfig;
  final bool loopPaused;
  final DateTime? nextRun;
  final String prompt;
  final String model;
  final bool enabled;
  final DateTime? lastRun;
  final String lastRunId;
  final String lastRunStatus;
  final String lastRunError;

  /// Mean duration of this task's recent completed runs, or null while it has
  /// never completed one.
  final int? averageRunSeconds;

  String get scheduleLabel =>
      triggerSummary.trim().isEmpty ? appStrings.taskTrigger : triggerSummary;
  String get lastRunLabel => lastRun == null ? '' : _formatTimestamp(lastRun!);
  String get lastRunStatusLabel =>
      _titleCase(lastRunStatus.replaceAll('_', ' '));
  bool get hasLastRunStatus => lastRunStatus.trim().isNotEmpty;
  bool get lastRunFailed =>
      lastRunStatus == 'failed' || lastRunStatus == 'error';
  bool get hasModelOverride => model.trim().isNotEmpty;
}

class McpServerItem {
  const McpServerItem({
    required this.id,
    required this.agentId,
    required this.name,
    required this.command,
    required this.config,
    required this.enabled,
    required this.status,
    required this.toolCount,
    required this.error,
    required this.consecutiveFails,
    required this.nextRetryAt,
  });

  factory McpServerItem.fromJson(Map<dynamic, dynamic> json) {
    return McpServerItem(
      id: _asInt(json['id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString() ?? appStrings.mcpServer2,
      command: json['command']?.toString() ?? '',
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const <String, dynamic>{},
      enabled: json['enabled'] == true,
      status: json['status']?.toString().ifEmpty('stopped') ?? 'stopped',
      toolCount: _asInt(json['toolCount']),
      error: json['error']?.toString(),
      consecutiveFails: _asInt(json['consecutiveFails']),
      nextRetryAt: _parseOptionalTimestamp(json['nextRetryAt']?.toString()),
    );
  }

  final int id;
  final String? agentId;
  final String name;
  final String command;
  final Map<String, dynamic> config;
  final bool enabled;
  final String status;
  final int toolCount;
  final String? error;
  final int consecutiveFails;
  final DateTime? nextRetryAt;

  bool get hasError => (error ?? '').trim().isNotEmpty;
  String get retryLabel => nextRetryAt == null
      ? ''
      : appStrings.nextRetryArg1(_formatTimestamp(nextRetryAt!));

  String get authMethodLabel {
    final auth = _jsonMap(config['auth']);
    final type = auth['type']?.toString().ifEmpty('none') ?? 'none';
    switch (type) {
      case 'bearer':
        return appStrings.bearerToken;
      case 'oauth':
        return 'OAuth';
      default:
        return appStrings.noAuth;
    }
  }
}

class AccountSessionItem {
  const AccountSessionItem({
    required this.id,
    required this.current,
    required this.ipAddress,
    required this.userAgent,
    required this.location,
    required this.createdAt,
    required this.lastSeenAt,
    required this.expiresAt,
  });

  factory AccountSessionItem.fromJson(Map<dynamic, dynamic> json) {
    return AccountSessionItem(
      id: _asInt(json['id']),
      current: json['current'] == true,
      ipAddress: json['ipAddress']?.toString() ?? '',
      userAgent: json['userAgent']?.toString() ?? '',
      location: json['location']?.toString().ifEmpty('Unknown') ?? 'Unknown',
      createdAt: _parseOptionalTimestamp(json['createdAt']?.toString()),
      lastSeenAt: _parseOptionalTimestamp(json['lastSeenAt']?.toString()),
      expiresAt: _parseOptionalTimestamp(json['expiresAt']?.toString()),
    );
  }

  final int id;
  final bool current;
  final String ipAddress;
  final String userAgent;
  final String location;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? expiresAt;

  _SessionClientInfo get _clientInfo => _SessionClientInfo.parse(userAgent);

  IconData get deviceIcon => switch (_clientInfo.deviceClass) {
    _SessionDeviceClass.mobile => Icons.smartphone_rounded,
    _SessionDeviceClass.tablet => Icons.tablet_mac_rounded,
    _SessionDeviceClass.desktop => Icons.laptop_mac_rounded,
    _SessionDeviceClass.server => Icons.dns_outlined,
    _SessionDeviceClass.unknown => Icons.devices_other_rounded,
  };

  String get clientPlatformLabel => _clientInfo.platformLabel;

  String get clientBrowserLabel => _clientInfo.browserLabel;

  String get clientLabel {
    final parts = <String>[
      clientPlatformLabel,
      if (clientBrowserLabel.isNotEmpty &&
          clientBrowserLabel != appStrings.unknownBrowser)
        clientBrowserLabel,
    ];
    return parts.join(' · ').ifEmpty(appStrings.unknownDevice);
  }

  String get locationSummary {
    final parts = <String>[
      if (location.trim().isNotEmpty) location.trim(),
      if (ipAddress.trim().isNotEmpty) ipAddress.trim(),
    ];
    return parts.join(' · ').ifEmpty(appStrings.unknownLocation);
  }

  String get lastSeenLabel =>
      lastSeenAt == null ? appStrings.notRecorded : _formatTimestamp(lastSeenAt!);
  String get createdLabel =>
      createdAt == null ? appStrings.notRecorded : _formatTimestamp(createdAt!);
  String get expiresLabel =>
      expiresAt == null ? appStrings.sessionCookie : _formatTimestamp(expiresAt!);
}

enum _SessionDeviceClass { desktop, mobile, tablet, server, unknown }

class _SessionClientInfo {
  const _SessionClientInfo({
    required this.platformLabel,
    required this.browserLabel,
    required this.deviceClass,
  });

  factory _SessionClientInfo.parse(String userAgent) {
    final raw = userAgent.trim();
    if (raw.isEmpty) {
      return _SessionClientInfo(
        platformLabel: appStrings.unknownDevice,
        browserLabel: appStrings.unknownBrowser,
        deviceClass: _SessionDeviceClass.unknown,
      );
    }

    final lower = raw.toLowerCase();
    final isTablet = lower.contains('ipad') || lower.contains('tablet');
    final isMobile =
        !isTablet &&
        (lower.contains('iphone') ||
            lower.contains('android') && lower.contains('mobile'));

    final platformLabel = switch (true) {
      _ when lower.contains('iphone') => 'iPhone',
      _ when lower.contains('ipad') => 'iPad',
      _ when lower.contains('android') => 'Android',
      _ when lower.contains('mac os x') || lower.contains('macintosh') =>
        'macOS',
      _ when lower.contains('windows nt') => 'Windows',
      _ when lower.contains('linux') => 'Linux',
      _ when lower.contains('x11') => 'Linux',
      _
          when lower.contains('curl/') ||
              lower.contains('wget/') ||
              lower.contains('httpie/') =>
        appStrings.cliSession,
      _ => appStrings.unknownDevice,
    };

    final browserLabel = switch (true) {
      _ when lower.contains('edg/') => 'Edge',
      _ when lower.contains('opr/') || lower.contains('opera/') => 'Opera',
      _ when lower.contains('brave/') => 'Brave',
      _ when lower.contains('firefox/') => 'Firefox',
      _
          when lower.contains('chrome/') ||
              lower.contains('crios/') ||
              lower.contains('chromium/') =>
        'Chrome',
      _ when lower.contains('safari/') && lower.contains('version/') =>
        'Safari',
      _ when lower.contains('curl/') => 'curl',
      _ when lower.contains('wget/') => 'wget',
      _ when lower.contains('httpie/') => 'HTTPie',
      _ => appStrings.unknownBrowser,
    };

    final deviceClass = switch (true) {
      _ when platformLabel == appStrings.cliSession => _SessionDeviceClass.server,
      _ when isTablet => _SessionDeviceClass.tablet,
      _ when isMobile => _SessionDeviceClass.mobile,
      _
          when platformLabel == 'macOS' ||
              platformLabel == 'Windows' ||
              platformLabel == 'Linux' =>
        _SessionDeviceClass.desktop,
      _ => _SessionDeviceClass.unknown,
    };

    return _SessionClientInfo(
      platformLabel: platformLabel,
      browserLabel: browserLabel,
      deviceClass: deviceClass,
    );
  }

  final String platformLabel;
  final String browserLabel;
  final _SessionDeviceClass deviceClass;
}

class AuthProviderCatalogItem {
  const AuthProviderCatalogItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.configured,
    required this.summary,
  });

  factory AuthProviderCatalogItem.fromJson(Map<dynamic, dynamic> json) {
    return AuthProviderCatalogItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      configured: json['configured'] == true,
      summary: json['summary']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String icon;
  final bool configured;
  final String summary;
}

class SecurityKeyItem {
  const SecurityKeyItem({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lastUsedAt,
    required this.backedUp,
  });

  factory SecurityKeyItem.fromJson(Map<dynamic, dynamic> json) {
    return SecurityKeyItem(
      id: _asInt(json['id']),
      label: json['label']?.toString() ?? appStrings.securityKey,
      createdAt: _parseOptionalTimestamp(json['createdAt']?.toString()),
      lastUsedAt: _parseOptionalTimestamp(json['lastUsedAt']?.toString()),
      backedUp: json['backedUp'] == true,
    );
  }

  final int id;
  final String label;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool backedUp;

  String get addedLabel =>
      createdAt == null ? appStrings.notRecorded : _formatTimestamp(createdAt!);
  String get lastUsedLabel =>
      lastUsedAt == null ? appStrings.neverUsed : _formatTimestamp(lastUsedAt!);
}

class LinkedAuthProviderItem {
  const LinkedAuthProviderItem({
    required this.id,
    required this.provider,
    required this.label,
    required this.icon,
    required this.email,
    required this.lastUsedAt,
    required this.linkedAt,
    required this.canUnlink,
    required this.metadata,
  });

  factory LinkedAuthProviderItem.fromJson(Map<dynamic, dynamic> json) {
    return LinkedAuthProviderItem(
      id: _asInt(json['id']),
      provider: json['provider']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      lastUsedAt: _parseOptionalTimestamp(json['lastUsedAt']?.toString()),
      linkedAt: _parseOptionalTimestamp(json['linkedAt']?.toString()),
      canUnlink: json['canUnlink'] == true,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  final int id;
  final String provider;
  final String label;
  final String icon;
  final String email;
  final DateTime? lastUsedAt;
  final DateTime? linkedAt;
  final bool canUnlink;
  final Map<String, dynamic> metadata;

  String get avatarUrl => metadata['avatarUrl']?.toString() ?? '';
  String get displayName => metadata['displayName']?.toString() ?? '';
  String get linkedAtLabel =>
      linkedAt == null ? appStrings.linkedRecently : _formatTimestamp(linkedAt!);
  String get lastUsedLabel =>
      lastUsedAt == null ? appStrings.notUsedYet : _formatTimestamp(lastUsedAt!);
}

class QrLoginChallenge {
  const QrLoginChallenge({
    required this.challengeId,
    required this.pollToken,
    required this.qrPayload,
    required this.backendUrl,
    required this.status,
    required this.expiresAt,
  });

  factory QrLoginChallenge.fromJson(Map<dynamic, dynamic> json) {
    return QrLoginChallenge(
      challengeId: json['challengeId']?.toString() ?? '',
      pollToken: json['pollToken']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      backendUrl: json['backendUrl']?.toString() ?? '',
      status: json['status']?.toString().ifEmpty('pending') ?? 'pending',
      expiresAt: _parseOptionalTimestamp(json['expiresAt']?.toString()),
    );
  }

  final String challengeId;
  final String pollToken;
  final String qrPayload;
  final String backendUrl;
  final String status;
  final DateTime? expiresAt;

  bool get isUsable =>
      challengeId.isNotEmpty &&
      pollToken.isNotEmpty &&
      qrPayload.isNotEmpty &&
      status != 'expired';

  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  int get secondsRemaining {
    final expires = expiresAt;
    if (expires == null) return 0;
    final diff = expires.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }
}

class QrLoginApprovalPreview {
  const QrLoginApprovalPreview({
    required this.challengeId,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    required this.approvedAt,
    required this.claimedAt,
    required this.requestedDevice,
    required this.requestLocation,
  });

  factory QrLoginApprovalPreview.fromJson(Map<dynamic, dynamic> json) {
    return QrLoginApprovalPreview(
      challengeId: json['challengeId']?.toString() ?? '',
      status: json['status']?.toString().ifEmpty('pending') ?? 'pending',
      requestedAt: _parseOptionalTimestamp(json['requestedAt']?.toString()),
      expiresAt: _parseOptionalTimestamp(json['expiresAt']?.toString()),
      approvedAt: _parseOptionalTimestamp(json['approvedAt']?.toString()),
      claimedAt: _parseOptionalTimestamp(json['claimedAt']?.toString()),
      requestedDevice: QrLoginRequestedDevice.fromJson(
        json['requestedDevice'] is Map
            ? json['requestedDevice'] as Map
            : const <String, dynamic>{},
      ),
      requestLocation: QrLoginRequestLocation.fromJson(
        json['requestLocation'] is Map
            ? json['requestLocation'] as Map
            : const <String, dynamic>{},
      ),
    );
  }

  final String challengeId;
  final String status;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final DateTime? approvedAt;
  final DateTime? claimedAt;
  final QrLoginRequestedDevice requestedDevice;
  final QrLoginRequestLocation requestLocation;

  bool get canApprove => status == 'pending' || status == 'approved';
  bool get isClaimed => status == 'claimed';
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
}

class QrLoginRequestedDevice {
  const QrLoginRequestedDevice({
    required this.label,
    required this.platformLabel,
    required this.browserLabel,
    required this.deviceClass,
    required this.userAgent,
    required this.metadata,
  });

  factory QrLoginRequestedDevice.fromJson(Map<dynamic, dynamic> json) {
    return QrLoginRequestedDevice(
      label:
          json['label']?.toString().ifEmpty(appStrings.unknownDevice) ??
          appStrings.unknownDevice,
      platformLabel:
          json['platformLabel']?.toString().ifEmpty('Unknown') ?? 'Unknown',
      browserLabel:
          json['browserLabel']?.toString().ifEmpty('Unknown') ?? 'Unknown',
      deviceClass:
          json['deviceClass']?.toString().ifEmpty('unknown') ?? 'unknown',
      userAgent: json['userAgent']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  final String label;
  final String platformLabel;
  final String browserLabel;
  final String deviceClass;
  final String userAgent;
  final Map<String, dynamic> metadata;
}

class QrLoginRequestLocation {
  const QrLoginRequestLocation({
    required this.label,
    required this.ipAddress,
    required this.city,
    required this.region,
    required this.country,
    required this.timezone,
  });

  factory QrLoginRequestLocation.fromJson(Map<dynamic, dynamic> json) {
    return QrLoginRequestLocation(
      label: json['label']?.toString().ifEmpty('Unknown') ?? 'Unknown',
      ipAddress: json['ipAddress']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      country: json['country']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }

  final String label;
  final String? ipAddress;
  final String? city;
  final String? region;
  final String? country;
  final String? timezone;
}

class QrLoginScanPayload {
  const QrLoginScanPayload({
    required this.backendUrl,
    required this.challengeId,
    required this.secret,
    required this.version,
  });

  static QrLoginScanPayload? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme == 'neoagent' && uri.host == 'qr-login') {
        final backendUrl = uri.queryParameters['backend']?.trim() ?? '';
        final challengeId = uri.queryParameters['challenge']?.trim() ?? '';
        final secret = uri.queryParameters['secret']?.trim() ?? '';
        final version = uri.queryParameters['v']?.trim() ?? '1';
        if (backendUrl.isNotEmpty &&
            challengeId.isNotEmpty &&
            secret.isNotEmpty) {
          return QrLoginScanPayload(
            backendUrl: backendUrl,
            challengeId: challengeId,
            secret: secret,
            version: version,
          );
        }
      }
    } catch (_) {}

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      final backendUrl = decoded['backendUrl']?.toString().trim() ?? '';
      final challengeId = decoded['challengeId']?.toString().trim() ?? '';
      final secret = decoded['secret']?.toString().trim() ?? '';
      final version = decoded['version']?.toString().trim() ?? '1';
      if (backendUrl.isEmpty || challengeId.isEmpty || secret.isEmpty) {
        return null;
      }
      return QrLoginScanPayload(
        backendUrl: backendUrl,
        challengeId: challengeId,
        secret: secret,
        version: version,
      );
    } catch (_) {
      return null;
    }
  }

  final String backendUrl;
  final String challengeId;
  final String secret;
  final String version;
}

class ActiveRunState {
  const ActiveRunState({
    required this.runId,
    required this.title,
    required this.model,
    required this.triggerSource,
    required this.phase,
    required this.iteration,
    this.pendingSteeringCount = 0,
  });

  factory ActiveRunState.pending(String task) {
    return ActiveRunState(
      runId: 'pending',
      title: task,
      model: '',
      triggerSource: 'web',
      phase: 'Queued',
      iteration: 0,
      pendingSteeringCount: 0,
    );
  }

  final String runId;
  final String title;
  final String model;
  final String triggerSource;
  final String phase;
  final int iteration;
  final int pendingSteeringCount;

  ActiveRunState copyWith({
    String? runId,
    String? title,
    String? model,
    String? triggerSource,
    String? phase,
    int? iteration,
    int? pendingSteeringCount,
  }) {
    return ActiveRunState(
      runId: runId ?? this.runId,
      title: title ?? this.title,
      model: model ?? this.model,
      triggerSource: triggerSource ?? this.triggerSource,
      phase: phase ?? this.phase,
      iteration: iteration ?? this.iteration,
      pendingSteeringCount: pendingSteeringCount ?? this.pendingSteeringCount,
    );
  }
}

class ToolEventItem {
  const ToolEventItem({
    required this.id,
    required this.toolName,
    required this.type,
    required this.status,
    required this.summary,
  });

  final String id;
  final String toolName;
  final String type;
  final String status;
  final String summary;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  bool get isPlanningRelated =>
      type == 'analysis' || type == 'planning' || toolName == 'plan';

  bool get isHelperRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('subagent') || label.contains('helper');
  }

  bool get isBrowserRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('browser') ||
        label.contains('page') ||
        label.contains('screenshot');
  }

  bool get isMessagingRelated {
    final label = appStrings.arg1Arg23(type.toLowerCase(), toolName.toLowerCase());
    return label.contains('message') ||
        label.contains('telegram') ||
        label.contains('discord') ||
        label.contains('whatsapp') ||
        label.contains('slack');
  }

  bool get isWebRelated => isBrowserRelated || isMessagingRelated;

  String get laneLabel {
    if (isPlanningRelated) {
      return appStrings.planning;
    }
    if (isHelperRelated) {
      return appStrings.helper;
    }
    if (isWebRelated) {
      return appStrings.web;
    }
    if (type == 'verification') {
      return appStrings.verification;
    }
    return appStrings.execution;
  }

  IconData get laneIcon {
    if (isPlanningRelated) {
      return Icons.route_outlined;
    }
    if (isHelperRelated) {
      return Icons.account_tree_outlined;
    }
    if (isBrowserRelated) {
      return Icons.language_outlined;
    }
    if (isMessagingRelated) {
      return Icons.chat_bubble_outline;
    }
    if (type == 'verification') {
      return Icons.verified_outlined;
    }
    if (status == 'failed') {
      return Icons.error_outline;
    }
    return Icons.build_outlined;
  }

  String get compactSummary => _condenseRunText(summary, maxLength: 120);
}

class ChatPayloadOption {
  const ChatPayloadOption({required this.label, required this.value});

  final String label;
  final String value;
}

class ChatRichPayload {
  const ChatRichPayload({required this.type, required this.options});

  final String type;
  final List<ChatPayloadOption> options;
}

class AccountUsageAndLimits {
  const AccountUsageAndLimits({
    this.fourHourLimit,
    this.weeklyLimit,
    this.fourHourUsage = 0,
    this.weeklyUsage = 0,
    this.fourHourRemaining = 0,
    this.weeklyRemaining = 0,
    this.fourHourReached = false,
    this.weeklyReached = false,
    this.fourHourRecoversAt,
    this.weeklyRecoversAt,
    this.fourHourFullResetAt,
    this.weeklyFullResetAt,
    this.fourHourIsCustom = false,
    this.weeklyIsCustom = false,
  });

  factory AccountUsageAndLimits.fromJson(Map<String, dynamic> json) {
    final limits = json['limits'] is Map ? json['limits'] as Map : const {};
    final usage = json['usage'] is Map ? json['usage'] as Map : const {};
    final remaining = json['remaining'] is Map
        ? json['remaining'] as Map
        : const {};
    final reached = json['reached'] is Map ? json['reached'] as Map : const {};
    final recoversAt = json['recoversAt'] is Map
        ? json['recoversAt'] as Map
        : const {};
    final fullResetAt = json['fullResetAt'] is Map
        ? json['fullResetAt'] as Map
        : const {};
    return AccountUsageAndLimits(
      fourHourLimit: int.tryParse(limits['fourHour']?.toString() ?? ''),
      weeklyLimit: int.tryParse(limits['weekly']?.toString() ?? ''),
      fourHourUsage: _asInt(usage['fourHour']),
      weeklyUsage: _asInt(usage['weekly']),
      fourHourRemaining: _asInt(remaining['fourHour']),
      weeklyRemaining: _asInt(remaining['weekly']),
      fourHourReached: reached['fourHour'] == true,
      weeklyReached: reached['weekly'] == true,
      fourHourRecoversAt: DateTime.tryParse(
        recoversAt['fourHour']?.toString() ?? '',
      ),
      weeklyRecoversAt: DateTime.tryParse(
        recoversAt['weekly']?.toString() ?? '',
      ),
      fourHourFullResetAt: DateTime.tryParse(
        fullResetAt['fourHour']?.toString() ?? '',
      ),
      weeklyFullResetAt: DateTime.tryParse(
        fullResetAt['weekly']?.toString() ?? '',
      ),
      fourHourIsCustom: limits['fourHourIsCustom'] == true,
      weeklyIsCustom: limits['weeklyIsCustom'] == true,
    );
  }

  final int? fourHourLimit;
  final int? weeklyLimit;
  final int fourHourUsage;
  final int weeklyUsage;
  final int fourHourRemaining;
  final int weeklyRemaining;
  final bool fourHourReached;
  final bool weeklyReached;
  final DateTime? fourHourRecoversAt;
  final DateTime? weeklyRecoversAt;
  final DateTime? fourHourFullResetAt;
  final DateTime? weeklyFullResetAt;
  final bool fourHourIsCustom;
  final bool weeklyIsCustom;

  bool get hasLimits => fourHourLimit != null || weeklyLimit != null;
  bool get isReached => fourHourReached || weeklyReached;
}

// ── Delegated access (who manages whom) ─────────────────────────────────────

/// The only account fields the server shares across a delegation.
class AccessPerson {
  const AccessPerson({
    required this.id,
    required this.username,
    required this.displayName,
  });

  static AccessPerson? tryParse(Object? json) {
    if (json is! Map) return null;
    return AccessPerson(
      id: _asInt(json['id']),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
    );
  }

  final int id;
  final String username;
  final String displayName;

  String get label => displayName.isNotEmpty ? displayName : username;
}

class AccessPermission {
  const AccessPermission({
    required this.key,
    required this.allowed,
    required this.editable,
    required this.setBy,
  });

  factory AccessPermission.fromJson(Map<dynamic, dynamic> json) {
    return AccessPermission(
      key: json['key']?.toString() ?? '',
      allowed: json['allowed'] == true,
      editable: json['editable'] == true,
      setBy: AccessPerson.tryParse(json['setBy']),
    );
  }

  final String key;
  final bool allowed;

  /// Only present on the manager's view of an account they manage: false when
  /// an upstream manager took this permission away from the manager.
  final bool editable;

  /// The manager whose decision is in force, or null when nobody manages the
  /// account.
  final AccessPerson? setBy;
}

List<AccessPermission> _parseAccessPermissions(Object? raw) {
  if (raw is! List) return const <AccessPermission>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map(AccessPermission.fromJson)
      .toList(growable: false);
}

class ManagedBy {
  const ManagedBy({
    required this.manager,
    required this.since,
    required this.chain,
  });

  static ManagedBy? tryParse(Object? json) {
    if (json is! Map) return null;
    final manager = AccessPerson.tryParse(json['manager']);
    if (manager == null) return null;
    final chain = json['chain'];
    return ManagedBy(
      manager: manager,
      since: _parseOptionalTimestamp(json['since']?.toString()),
      chain: chain is List
          ? chain
                .map(AccessPerson.tryParse)
                .whereType<AccessPerson>()
                .toList(growable: false)
          : <AccessPerson>[manager],
    );
  }

  final AccessPerson manager;
  final DateTime? since;

  /// Direct manager first, then theirs, up to the top of the chain.
  final List<AccessPerson> chain;
}

class ManagedAccount {
  const ManagedAccount({
    required this.person,
    required this.since,
    required this.permissions,
  });

  static ManagedAccount? tryParse(Object? json) {
    if (json is! Map) return null;
    final person = AccessPerson.tryParse(json['user']);
    if (person == null) return null;
    return ManagedAccount(
      person: person,
      since: _parseOptionalTimestamp(json['since']?.toString()),
      permissions: _parseAccessPermissions(json['permissions']),
    );
  }

  final AccessPerson person;
  final DateTime? since;
  final List<AccessPermission> permissions;
}

class DelegationInvite {
  const DelegationInvite({
    required this.id,
    required this.label,
    required this.permissions,
    required this.singleUse,
    required this.useCount,
    required this.expiresAt,
    required this.createdAt,
    required this.status,
  });

  factory DelegationInvite.fromJson(Map<dynamic, dynamic> json) {
    final permissions = json['permissions'];
    return DelegationInvite(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      permissions: permissions is List
          ? permissions.map((key) => key.toString()).toList(growable: false)
          : const <String>[],
      singleUse: json['maxUses'] == 1,
      useCount: _asInt(json['useCount']),
      expiresAt: _parseOptionalTimestamp(json['expiresAt']?.toString()),
      createdAt: _parseOptionalTimestamp(json['createdAt']?.toString()),
      status: json['status']?.toString() ?? 'active',
    );
  }

  final String id;
  final String label;
  final List<String> permissions;
  final bool singleUse;
  final int useCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  /// `active`, `expired`, `revoked` or `used`.
  final String status;

  bool get isActive => status == 'active';
}

class AccessSummary {
  const AccessSummary({
    required this.isAdmin,
    required this.catalog,
    required this.maxDepth,
    required this.permissions,
    required this.managedBy,
    required this.managing,
    required this.invites,
  });

  factory AccessSummary.fromJson(Map<dynamic, dynamic> json) {
    final catalog = json['catalog'];
    final managing = json['managing'];
    final invites = json['invites'];
    return AccessSummary(
      isAdmin: json['isAdmin'] == true,
      catalog: catalog is List
          ? catalog.map((key) => key.toString()).toList(growable: false)
          : const <String>[],
      maxDepth: _asInt(json['maxDepth']),
      permissions: _parseAccessPermissions(json['permissions']),
      managedBy: ManagedBy.tryParse(json['managedBy']),
      managing: managing is List
          ? managing
                .map(ManagedAccount.tryParse)
                .whereType<ManagedAccount>()
                .toList(growable: false)
          : const <ManagedAccount>[],
      invites: invites is List
          ? invites
                .whereType<Map<dynamic, dynamic>>()
                .map(DelegationInvite.fromJson)
                .toList(growable: false)
          : const <DelegationInvite>[],
    );
  }

  final bool isAdmin;
  final List<String> catalog;
  final int maxDepth;
  final List<AccessPermission> permissions;
  final ManagedBy? managedBy;
  final List<ManagedAccount> managing;
  final List<DelegationInvite> invites;
}

/// What a pasted invite link would do, shown before the user confirms.
class DelegationInvitePreview {
  const DelegationInvitePreview({
    required this.issuer,
    required this.permissions,
    required this.expiresAt,
    required this.singleUse,
  });

  factory DelegationInvitePreview.fromJson(Map<dynamic, dynamic> json) {
    final permissions = json['permissions'];
    return DelegationInvitePreview(
      issuer:
          AccessPerson.tryParse(json['issuer']) ??
          const AccessPerson(id: 0, username: '', displayName: ''),
      permissions: permissions is List
          ? permissions.map((key) => key.toString()).toList(growable: false)
          : const <String>[],
      expiresAt: _parseOptionalTimestamp(json['expiresAt']?.toString()),
      singleUse: json['singleUse'] == true,
    );
  }

  final AccessPerson issuer;
  final List<String> permissions;
  final DateTime? expiresAt;
  final bool singleUse;
}
