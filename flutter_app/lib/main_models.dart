part of 'main.dart';

const List<MessagingPlatformDescriptor>
messagingPlatforms = <MessagingPlatformDescriptor>[
  MessagingPlatformDescriptor(
    id: 'whatsapp',
    label: 'WhatsApp',
    subtitle: 'QR-based phone linking',
    accent: Color(0xFF25D366),
    connectMethod: MessagingConnectMethod.qr,
    icon: Icons.chat_bubble,
  ),
  MessagingPlatformDescriptor(
    id: 'telegram',
    label: 'Telegram',
    subtitle: 'Bot token and approved chats',
    accent: Color(0xFF2AABEE),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.send_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'botToken', label: 'Bot Token', obscure: true),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'discord',
    label: 'Discord',
    subtitle: 'Bot token and server/channel access',
    accent: Color(0xFF5865F2),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.sports_esports_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'token', label: 'Bot Token', obscure: true),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'slack',
    label: 'Slack',
    subtitle: 'Bot token, Events API, and channel access',
    accent: Color(0xFF36C5F0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.tag_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'botToken', label: 'Bot Token', obscure: true),
      MessagingConfigField(
        key: 'signingSecret',
        label: 'Signing Secret',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'google_chat',
    label: 'Google Chat',
    subtitle: 'Space webhook and app callback support',
    accent: Color(0xFF34A853),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.forum_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: 'Webhook URL',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
      MessagingConfigField(key: 'defaultTo', label: 'Default Space / Chat ID'),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'teams',
    label: 'Microsoft Teams',
    subtitle: 'Incoming webhook and outgoing callback support',
    accent: Color(0xFF6264A7),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.groups_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: 'Webhook URL',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
      MessagingConfigField(key: 'defaultTo', label: 'Default Conversation ID'),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'matrix',
    label: 'Matrix',
    subtitle: 'Homeserver token with room polling',
    accent: Color(0xFF0DBD8B),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.grid_view_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'homeserver', label: 'Homeserver URL'),
      MessagingConfigField(
        key: 'accessToken',
        label: 'Access Token',
        obscure: true,
      ),
      MessagingConfigField(key: 'userId', label: 'User ID'),
      MessagingConfigField(
        key: 'pollIntervalMs',
        label: 'Poll Interval ms',
        defaultValue: '5000',
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'signal',
    label: 'Signal',
    subtitle: 'signal-cli REST API bridge',
    accent: Color(0xFF3A76F0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.lock_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'restUrl', label: 'signal-cli REST API URL'),
      MessagingConfigField(key: 'account', label: 'Account Number'),
      MessagingConfigField(
        key: 'pollEnabled',
        label: 'Enable receive polling',
        kind: MessagingConfigFieldKind.boolean,
      ),
      MessagingConfigField(
        key: 'pollIntervalMs',
        label: 'Poll Interval ms',
        defaultValue: '10000',
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'imessage',
    label: 'iMessage',
    subtitle: 'BlueBubbles-compatible bridge',
    accent: Color(0xFF007AFF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.sms_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'serverUrl', label: 'BlueBubbles Server URL'),
      MessagingConfigField(
        key: 'password',
        label: 'Password / API Key',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'sendPath',
        label: 'Send Path',
        defaultValue: '/api/v1/message/text',
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'bluebubbles',
    label: 'BlueBubbles',
    subtitle: 'Direct BlueBubbles iMessage bridge',
    accent: Color(0xFF0A84FF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.bubble_chart_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'serverUrl', label: 'BlueBubbles Server URL'),
      MessagingConfigField(
        key: 'password',
        label: 'Password / API Key',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'sendPath',
        label: 'Send Path',
        defaultValue: '/api/v1/message/text',
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'irc',
    label: 'IRC',
    subtitle: 'Server, nick, channel, and optional TLS',
    accent: Color(0xFF7E57C2),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.terminal_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'server', label: 'Server'),
      MessagingConfigField(key: 'port', label: 'Port', defaultValue: '6667'),
      MessagingConfigField(key: 'nick', label: 'Nickname'),
      MessagingConfigField(key: 'password', label: 'Password', obscure: true),
      MessagingConfigField(key: 'channels', label: 'Channels, comma-separated'),
      MessagingConfigField(
        key: 'tls',
        label: 'Use TLS',
        kind: MessagingConfigFieldKind.boolean,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'twitch',
    label: 'Twitch',
    subtitle: 'Twitch chat over IRC',
    accent: Color(0xFF9146FF),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.live_tv_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'nick', label: 'Bot Username'),
      MessagingConfigField(
        key: 'oauthToken',
        label: 'OAuth Token',
        obscure: true,
      ),
      MessagingConfigField(key: 'channels', label: 'Channels, comma-separated'),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'line',
    label: 'LINE',
    subtitle: 'Messaging API push and webhook events',
    accent: Color(0xFF06C755),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.chat_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'channelAccessToken',
        label: 'Channel Access Token',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'mattermost',
    label: 'Mattermost',
    subtitle: 'Webhook or REST channel posting',
    accent: Color(0xFF0058CC),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.forum_outlined,
    configFields: <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: 'Webhook URL',
        obscure: true,
      ),
      MessagingConfigField(key: 'baseUrl', label: 'Base URL'),
      MessagingConfigField(key: 'token', label: 'Access Token', obscure: true),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'meshtastic',
    label: 'Meshtastic',
    subtitle: 'TCP bridge to a local device channel',
    accent: Color(0xFF2E7D32),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.router_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'host', label: 'Device IP Address'),
      MessagingConfigField(
        key: 'channel',
        label: 'Channel Index',
        defaultValue: '0',
      ),
    ],
  ),
  MessagingPlatformDescriptor(
    id: 'telnyx',
    label: 'Telnyx Voice',
    subtitle: 'Inbound and outbound calling',
    accent: Color(0xFF00C8A0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.call_rounded,
  ),
  ...longTailMessagingPlatforms,
];

const List<MessagingPlatformDescriptor> longTailMessagingPlatforms =
    <MessagingPlatformDescriptor>[
      MessagingPlatformDescriptor(
        id: 'feishu',
        label: 'Feishu',
        subtitle: 'Configurable webhook bridge',
        accent: Color(0xFF3370FF),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.webhook_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'nextcloud_talk',
        label: 'Nextcloud Talk',
        subtitle: 'Configurable Talk webhook bridge',
        accent: Color(0xFF0082C9),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.cloud_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'nostr',
        label: 'Nostr',
        subtitle: 'Configurable relay or webhook bridge',
        accent: Color(0xFF9C27B0),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.hub_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'synology_chat',
        label: 'Synology Chat',
        subtitle: 'Configurable webhook bridge',
        accent: Color(0xFF1E88E5),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.storage_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'tlon',
        label: 'Tlon',
        subtitle: 'Configurable webhook bridge',
        accent: Color(0xFF111111),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.blur_on_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'zalo',
        label: 'Zalo',
        subtitle: 'Configurable webhook bridge',
        accent: Color(0xFF0068FF),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.message_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'zalo_personal',
        label: 'Zalo Personal',
        subtitle: 'Configurable personal webhook bridge',
        accent: Color(0xFF0288D1),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.person_pin_circle_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'wechat',
        label: 'WeChat',
        subtitle: 'Configurable webhook bridge',
        accent: Color(0xFF07C160),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.chat_bubble_outline_rounded,
        configFields: genericWebhookConfigFields,
      ),
      MessagingPlatformDescriptor(
        id: 'webchat',
        label: 'WebChat',
        subtitle: 'Configurable web inbox bridge',
        accent: Color(0xFF00A1F1),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.public_rounded,
        configFields: genericWebhookConfigFields,
      ),
    ];

const List<MessagingConfigField> genericWebhookConfigFields =
    <MessagingConfigField>[
      MessagingConfigField(
        key: 'webhookUrl',
        label: 'Outbound Webhook URL',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'outboundUrl',
        label: 'Custom Outbound URL',
        obscure: true,
      ),
      MessagingConfigField(key: 'token', label: 'Access Token', obscure: true),
      MessagingConfigField(
        key: 'inboundSecret',
        label: 'Inbound Secret',
        obscure: true,
      ),
      MessagingConfigField(
        key: 'contentField',
        label: 'Content Field',
        defaultValue: 'text',
      ),
      MessagingConfigField(key: 'recipientField', label: 'Recipient Field'),
      MessagingConfigField(
        key: 'headers',
        label: 'Headers JSON',
        kind: MessagingConfigFieldKind.multiline,
      ),
      MessagingConfigField(
        key: 'bodyTemplate',
        label: 'Body Template JSON',
        kind: MessagingConfigFieldKind.multiline,
      ),
    ];

enum MessagingConnectMethod { qr, config }

enum MessagingConfigFieldKind { text, password, multiline, boolean }

class MessagingConfigField {
  const MessagingConfigField({
    required this.key,
    required this.label,
    this.kind = MessagingConfigFieldKind.text,
    this.obscure = false,
    this.defaultValue,
    this.settingsKey,
    this.includeInConfig = true,
  });

  final String key;
  final String label;
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
  });

  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final MessagingConnectMethod connectMethod;
  final IconData icon;
  final List<MessagingConfigField> configFields;
  final MessagingAccessCapabilities? accessCapabilities;

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
  bool get isConnecting => status == 'connecting' || status == 'awaiting_qr';

  String get statusLabel => status.replaceAll('_', ' ');

  String get authLabel {
    for (final key in <String>['phoneNumber', 'tag', 'username', 'label']) {
      final value = authInfo[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return key == 'username' ? '@$value' : value;
      }
    }
    if (lastConnected != null) {
      return 'Last seen ${_formatTimestamp(lastConnected!)}';
    }
    return 'Not connected';
  }

  Color get badgeColor {
    switch (status) {
      case 'connected':
        return _success;
      case 'awaiting_qr':
      case 'connecting':
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
    );
  }

  factory MessagingMessage.fromBlockedNotice(BlockedSenderNotice notice) {
    final summary = <String>[
      'Blocked incoming message from ${notice.senderLabel}.',
      if (notice.meta.isNotEmpty) notice.meta,
      if (notice.suggestions.isNotEmpty)
        'Suggestions: ${notice.suggestions.map((item) => item.label).join(', ')}',
      'Update the access list to allow replies.',
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

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get senderLabel {
    if (outgoing) {
      return target?.ifEmpty('Outgoing message') ?? 'Outgoing message';
    }
    return senderName?.ifEmpty(sender ?? platform.toUpperCase()) ??
        sender?.ifEmpty(platform.toUpperCase()) ??
        platform.toUpperCase();
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

class MessagingAccessRule {
  const MessagingAccessRule({
    required this.scope,
    required this.value,
    this.label,
  });

  factory MessagingAccessRule.fromJson(Map<String, dynamic> json) {
    return MessagingAccessRule(
      scope: json['scope']?.toString() ?? 'chat',
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString(),
    );
  }

  final String scope;
  final String value;
  final String? label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scope': scope,
    'value': value,
    if (label != null && label!.trim().isNotEmpty) 'label': label,
  };

  String get id => '$scope:$value';

  String get displayLabel => label?.ifEmpty(value) ?? value;

  String get scopeLabel {
    switch (scope) {
      case 'phone_number':
        return 'Number';
      case 'server':
        return 'Server';
      case 'channel':
        return 'Channel';
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
        return 'Chat';
    }
  }
}

class MessagingAccessPolicy {
  const MessagingAccessPolicy({
    required this.directPolicy,
    required this.sharedPolicy,
    required this.requireMentionInShared,
    required this.directRules,
    required this.sharedSpaceRules,
    required this.sharedActorRules,
  });

  factory MessagingAccessPolicy.fromJson(Map<String, dynamic> json) {
    return MessagingAccessPolicy(
      directPolicy:
          json['directPolicy']?.toString().ifEmpty('allowlist') ?? 'allowlist',
      sharedPolicy:
          json['sharedPolicy']?.toString().ifEmpty('allowlist') ?? 'allowlist',
      requireMentionInShared: json['requireMentionInShared'] == true,
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
    );
  }

  const MessagingAccessPolicy.defaults({
    this.directPolicy = 'allowlist',
    this.sharedPolicy = 'allowlist',
    this.requireMentionInShared = true,
    this.directRules = const <MessagingAccessRule>[],
    this.sharedSpaceRules = const <MessagingAccessRule>[],
    this.sharedActorRules = const <MessagingAccessRule>[],
  });

  final String directPolicy;
  final String sharedPolicy;
  final bool requireMentionInShared;
  final List<MessagingAccessRule> directRules;
  final List<MessagingAccessRule> sharedSpaceRules;
  final List<MessagingAccessRule> sharedActorRules;

  MessagingAccessPolicy copyWith({
    String? directPolicy,
    String? sharedPolicy,
    bool? requireMentionInShared,
    List<MessagingAccessRule>? directRules,
    List<MessagingAccessRule>? sharedSpaceRules,
    List<MessagingAccessRule>? sharedActorRules,
  }) {
    return MessagingAccessPolicy(
      directPolicy: directPolicy ?? this.directPolicy,
      sharedPolicy: sharedPolicy ?? this.sharedPolicy,
      requireMentionInShared:
          requireMentionInShared ?? this.requireMentionInShared,
      directRules: directRules ?? this.directRules,
      sharedSpaceRules: sharedSpaceRules ?? this.sharedSpaceRules,
      sharedActorRules: sharedActorRules ?? this.sharedActorRules,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'directPolicy': directPolicy,
    'sharedPolicy': sharedPolicy,
    'requireMentionInShared': requireMentionInShared,
    'directRules': directRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedSpaceRules': sharedSpaceRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'sharedActorRules': sharedActorRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
  };

  int get totalRuleCount =>
      directRules.length + sharedSpaceRules.length + sharedActorRules.length;
}

class MessagingAccessCapabilities {
  const MessagingAccessCapabilities({
    this.supportsDirectPolicy = true,
    this.supportsSharedPolicy = true,
    this.supportsMentionGate = false,
    this.supportsDiscovery = false,
    this.directRuleScopes = const <String>[],
    this.sharedSpaceRuleScopes = const <String>[],
    this.sharedActorRuleScopes = const <String>[],
    this.manualEntryHint = '',
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
      supportsDiscovery: json['supportsDiscovery'] == true,
      directRuleScopes: stringList(json['directRuleScopes']),
      sharedSpaceRuleScopes: stringList(json['sharedSpaceRuleScopes']),
      sharedActorRuleScopes: stringList(json['sharedActorRuleScopes']),
      manualEntryHint: json['manualEntryHint']?.toString() ?? '',
    );
  }

  final bool supportsDirectPolicy;
  final bool supportsSharedPolicy;
  final bool supportsMentionGate;
  final bool supportsDiscovery;
  final List<String> directRuleScopes;
  final List<String> sharedSpaceRuleScopes;
  final List<String> sharedActorRuleScopes;
  final String manualEntryHint;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'supportsDirectPolicy': supportsDirectPolicy,
    'supportsSharedPolicy': supportsSharedPolicy,
    'supportsMentionGate': supportsMentionGate,
    'supportsDiscovery': supportsDiscovery,
    'directRuleScopes': directRuleScopes,
    'sharedSpaceRuleScopes': sharedSpaceRuleScopes,
    'sharedActorRuleScopes': sharedActorRuleScopes,
    'manualEntryHint': manualEntryHint,
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
  });

  factory MessagingAccessTarget.fromJson(Map<String, dynamic> json) {
    return MessagingAccessTarget(
      source: json['source']?.toString() ?? 'manual',
      bucket: json['bucket']?.toString() ?? 'sharedSpaceRules',
      scope: json['scope']?.toString() ?? 'chat',
      value: json['value']?.toString() ?? '',
      label:
          json['label']?.toString().ifEmpty(json['value']?.toString() ?? '') ??
          (json['value']?.toString() ?? ''),
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }

  final String source;
  final String bucket;
  final String scope;
  final String value;
  final String label;
  final String subtitle;

  MessagingAccessRule get asRule =>
      MessagingAccessRule(scope: scope, value: value, label: label);

  String get id => '$bucket:$scope:$value';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source,
    'bucket': bucket,
    'scope': scope,
    'value': value,
    'label': label,
    'subtitle': subtitle,
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
      summary: json['summary']?.toString() ?? 'Access policy',
    );
  }

  factory MessagingAccessCatalog.empty(String platform) {
    return MessagingAccessCatalog(
      platform: platform,
      policy: const MessagingAccessPolicy.defaults(),
      capabilities: const MessagingAccessCapabilities(),
      discoveredTargets: const <MessagingAccessTarget>[],
      suggestedTargets: const <MessagingAccessTarget>[],
      summary: 'Access policy',
    );
  }

  final String platform;
  final MessagingAccessPolicy policy;
  final MessagingAccessCapabilities capabilities;
  final List<MessagingAccessTarget> discoveredTargets;
  final List<MessagingAccessTarget> suggestedTargets;
  final String summary;
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
      return const QuickAllowSuggestion(
        label: 'Allow sender',
        bucket: 'sharedActorRules',
        rule: MessagingAccessRule(scope: 'chat', value: ''),
      );
    }
    return QuickAllowSuggestion(
      label:
          json['label']?.toString().ifEmpty('Allow sender') ?? 'Allow sender',
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
  if (platform == 'telnyx' || platform == 'whatsapp') {
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

class RecordingSessionItem {
  const RecordingSessionItem({
    required this.id,
    required this.title,
    required this.platform,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    required this.transcriptText,
    required this.lastError,
    required this.sources,
    required this.transcriptSegments,
    this.structuredContent = const <String, dynamic>{},
  });

  factory RecordingSessionItem.fromJson(Map<dynamic, dynamic> json) {
    final rawSources = json['sources'];
    final sourceRows = rawSources is List
        ? rawSources
        : rawSources is Map
        ? rawSources.values.toList(growable: false)
        : const <dynamic>[];
    final rawSegments = json['transcriptSegments'];
    final transcriptSegmentRows = rawSegments is List
        ? rawSegments
        : rawSegments is Map
        ? rawSegments.values.toList(growable: false)
        : const <dynamic>[];
    return RecordingSessionItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().ifEmpty('Recording') ?? 'Recording',
      platform: json['platform']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'recording',
      startedAt: _parseTimestamp(json['startedAt']?.toString()),
      endedAt: _parseOptionalTimestamp(json['endedAt']?.toString()),
      durationMs: _asInt(json['durationMs']),
      transcriptText: json['transcriptText']?.toString() ?? '',
      lastError: json['lastError']?.toString(),
      sources: sourceRows
          .whereType<Map<dynamic, dynamic>>()
          .map(RecordingSourceItem.fromJson)
          .toList(),
      transcriptSegments: transcriptSegmentRows
          .whereType<Map<dynamic, dynamic>>()
          .map(RecordingTranscriptSegment.fromJson)
          .toList(),
      structuredContent: _jsonMap(json['structuredContent']),
    );
  }

  final String id;
  final String title;
  final String platform;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMs;
  final String transcriptText;
  final String? lastError;
  final List<RecordingSourceItem> sources;
  final List<RecordingTranscriptSegment> transcriptSegments;
  final Map<String, dynamic> structuredContent;

  String get startedAtLabel => _formatTimestamp(startedAt);

  String get platformLabel {
    switch (platform) {
      case 'web':
        return 'Web';
      case 'android':
        return 'Android';
      default:
        return platform.ifEmpty('Unknown');
    }
  }

  String get durationLabel => _formatDuration(durationMs);

  String get statusLabel {
    switch (status) {
      case 'recording':
        return 'Recording';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'recording':
        return _danger;
      case 'processing':
        return _warning;
      case 'completed':
        return _success;
      case 'failed':
        return _danger;
      case 'cancelled':
        return _textSecondary;
      default:
        return _textSecondary;
    }
  }
}

class RecordingSourceItem {
  const RecordingSourceItem({
    required this.sourceKey,
    required this.sourceKind,
    required this.mediaKind,
    required this.mimeType,
    required this.durationMs,
    required this.chunkCount,
  });

  factory RecordingSourceItem.fromJson(Map<dynamic, dynamic> json) {
    return RecordingSourceItem(
      sourceKey: json['sourceKey']?.toString() ?? '',
      sourceKind: json['sourceKind']?.toString() ?? '',
      mediaKind: json['mediaKind']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      durationMs: _asInt(json['durationMs']),
      chunkCount: _asInt(json['chunkCount']),
    );
  }

  final String sourceKey;
  final String sourceKind;
  final String mediaKind;
  final String mimeType;
  final int durationMs;
  final int chunkCount;

  String get label {
    switch (sourceKind) {
      case 'screen-share':
        return 'Screen';
      case 'microphone':
        return 'Microphone';
      default:
        return sourceKind.ifEmpty(sourceKey);
    }
  }

  String get durationLabel => _formatDuration(durationMs);
}

class RecordingTranscriptSegment {
  const RecordingTranscriptSegment({
    required this.id,
    required this.speaker,
    required this.text,
    required this.startMs,
  });

  factory RecordingTranscriptSegment.fromJson(Map<dynamic, dynamic> json) {
    return RecordingTranscriptSegment(
      id: _asInt(json['id']),
      speaker:
          json['speaker']?.toString() ?? json['sourceKey']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      startMs: _asInt(json['startMs']),
    );
  }

  final int id;
  final String speaker;
  final String text;
  final int startMs;

  String get timestampLabel => _formatDuration(startMs);

  String get displayText {
    if (speaker.trim().isEmpty) {
      return text;
    }
    return '${speaker.replaceAll('-', ' ')}: $text';
  }
}

class VoiceAssistantTurnResult {
  const VoiceAssistantTurnResult({
    required this.session,
    required this.transcript,
    required this.replyText,
    required this.audioMimeType,
    required this.audioBytes,
    this.runId,
    this.ttsProvider,
    this.ttsModel,
    this.ttsVoice,
    this.ttsError,
  });

  factory VoiceAssistantTurnResult.fromJson(Map<dynamic, dynamic> json) {
    final audioBase64 = json['audioBase64']?.toString() ?? '';
    return VoiceAssistantTurnResult(
      session: RecordingSessionItem.fromJson(_jsonMap(json['session'])),
      transcript: json['transcript']?.toString() ?? '',
      replyText: json['replyText']?.toString() ?? '',
      audioMimeType: json['audioMimeType']?.toString() ?? 'audio/mpeg',
      audioBytes: audioBase64.trim().isEmpty
          ? Uint8List(0)
          : base64Decode(audioBase64),
      runId: json['runId']?.toString(),
      ttsProvider: json['ttsProvider']?.toString(),
      ttsModel: json['ttsModel']?.toString(),
      ttsVoice: json['ttsVoice']?.toString(),
      ttsError: json['ttsError']?.toString(),
    );
  }

  final RecordingSessionItem session;
  final String transcript;
  final String replyText;
  final String audioMimeType;
  final Uint8List audioBytes;
  final String? runId;
  final String? ttsProvider;
  final String? ttsModel;
  final String? ttsVoice;
  final String? ttsError;
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

class LiveVoiceBufferedChunk {
  LiveVoiceBufferedChunk({
    required this.sequence,
    required Uint8List bytes,
    this.sent = false,
  }) : bytes = Uint8List.fromList(bytes);

  final int sequence;
  final Uint8List bytes;
  bool sent;
}

class VoiceAssistantLiveState {
  VoiceAssistantLiveState({
    this.sessionId = '',
    this.runtimeMode = 'legacy',
    this.provider = 'openai',
    this.model = '',
    this.voice = '',
    this.transportState = 'connected',
    this.state = 'idle',
    this.partialTranscript = '',
    this.finalTranscript = '',
    this.interimAssistantText = '',
    this.finalAssistantText = '',
    this.assistantText = '',
    this.audioMimeType = 'audio/mpeg',
    List<Uint8List>? audioQueue,
    this.audioStreamDone = false,
    this.recoverableUntil,
    this.error,
  }) : audioQueue = audioQueue ?? const <Uint8List>[];

  final String sessionId;
  final String runtimeMode;
  final String provider;
  final String model;
  final String voice;
  final String transportState;
  final String state;
  final String partialTranscript;
  final String finalTranscript;
  final String interimAssistantText;
  final String finalAssistantText;
  final String assistantText;
  final String audioMimeType;
  final List<Uint8List> audioQueue;
  final bool audioStreamDone;
  final DateTime? recoverableUntil;
  final String? error;

  bool get hasActiveSession => sessionId.trim().isNotEmpty;
  bool get isLive => runtimeMode == 'live';
  bool get isListening => state == 'listening';
  bool get isBusy =>
      state == 'transcribing' || state == 'thinking' || state == 'speaking';
  bool get isRecoverable =>
      recoverableUntil != null && recoverableUntil!.isAfter(DateTime.now());

  VoiceAssistantLiveState copyWith({
    String? sessionId,
    String? runtimeMode,
    String? provider,
    String? model,
    String? voice,
    String? transportState,
    String? state,
    String? partialTranscript,
    String? finalTranscript,
    String? interimAssistantText,
    String? finalAssistantText,
    String? assistantText,
    String? audioMimeType,
    List<Uint8List>? audioQueue,
    bool? audioStreamDone,
    DateTime? recoverableUntil,
    String? error,
    bool clearError = false,
    bool clearAudio = false,
    bool clearRecoverableUntil = false,
  }) {
    return VoiceAssistantLiveState(
      sessionId: sessionId ?? this.sessionId,
      runtimeMode: runtimeMode ?? this.runtimeMode,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      transportState: transportState ?? this.transportState,
      state: state ?? this.state,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      interimAssistantText: interimAssistantText ?? this.interimAssistantText,
      finalAssistantText: finalAssistantText ?? this.finalAssistantText,
      assistantText: assistantText ?? this.assistantText,
      audioMimeType: audioMimeType ?? this.audioMimeType,
      audioQueue: clearAudio
          ? const <Uint8List>[]
          : (audioQueue ?? this.audioQueue),
      audioStreamDone: clearAudio
          ? false
          : (audioStreamDone ?? this.audioStreamDone),
      recoverableUntil: clearRecoverableUntil
          ? null
          : (recoverableUntil ?? this.recoverableUntil),
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
    final label = '${step.type} ${step.toolName}'.toLowerCase();
    return label.contains('subagent') || label.contains('helper');
  }).length;

  int get webStepCount => steps.where((step) => step.isWebRelated).length;

  int get planningStepCount =>
      steps.where((step) => step.isPlanningRelated).length;
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
        return 'Deliverable selected';
      case 'deliverable_execution_started':
        return 'Deliverable execution started';
      case 'deliverable_artifact_produced':
        return 'Deliverable artifact produced';
      case 'deliverable_validation_started':
        return 'Deliverable validation started';
      case 'deliverable_validation_failed':
        return 'Deliverable validation failed';
      case 'deliverable_completed':
        return 'Deliverable completed';
      case 'run_started':
        return 'Run started';
      case 'memory_injected':
        return 'Memory injected';
      case 'model_turn_started':
        return 'Model turn started';
      case 'model_turn_completed':
        return 'Model turn completed';
      case 'tool_started':
        return 'Tool started';
      case 'tool_completed':
        return 'Tool completed';
      case 'tool_failed':
        return 'Tool failed';
      case 'run_completed':
        return 'Run completed';
      case 'run_failed':
        return 'Run failed';
      case 'run_stopped':
        return 'Run stopped';
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
    return description.ifEmpty('No details captured.');
  }

  String get compactSummary => _condenseRunText(summary, maxLength: 140);

  String get laneLabel {
    if (isPlanningRelated) {
      return 'Planning';
    }
    if (isHelperRelated) {
      return 'Helper';
    }
    if (isWebRelated) {
      return 'Web';
    }
    if (type == 'verification') {
      return 'Verification';
    }
    return 'Execution';
  }

  bool get isPlanningRelated =>
      type == 'analysis' || type == 'planning' || toolName == 'analysis';

  bool get isHelperRelated {
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
    return label.contains('subagent') || label.contains('helper');
  }

  bool get isBrowserRelated {
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
    return label.contains('browser') ||
        label.contains('page') ||
        label.contains('screenshot');
  }

  bool get isMessagingRelated {
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
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
        return _warning;
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
        json['displayName']?.toString().ifEmpty('Agent') ??
        json['display_name']?.toString().ifEmpty('Agent') ??
        'Agent';
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
  String get label => isDefault ? '$displayName (default)' : displayName;
  bool get delegatesToAnyEligibleAgent =>
      canDelegate && delegateTargets.isEmpty;
}

class ModelMeta {
  const ModelMeta({
    required this.id,
    required this.label,
    required this.provider,
    required this.purpose,
    this.available = true,
    this.providerStatus = '',
    this.providerStatusLabel = '',
  });

  factory ModelMeta.fromJson(Map<dynamic, dynamic> json) {
    return ModelMeta(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      available: json['available'] != false,
      providerStatus: json['providerStatus']?.toString() ?? '',
      providerStatusLabel: json['providerStatusLabel']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String provider;
  final String purpose;
  final bool available;
  final String providerStatus;
  final String providerStatusLabel;
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.enabled,
    required this.baseUrl,
  });

  factory AiProviderConfig.empty(String id) {
    return AiProviderConfig(
      id: id,
      enabled: true,
      baseUrl: id == 'ollama' ? 'http://localhost:11434' : '',
    );
  }

  factory AiProviderConfig.fromJson(String id, dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    return AiProviderConfig(
      id: id,
      enabled: map['enabled'] != false,
      baseUrl:
          map['baseUrl']?.toString() ??
          (id == 'ollama' ? 'http://localhost:11434' : ''),
    );
  }

  final String id;
  final bool enabled;
  final String baseUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'enabled': enabled, 'baseUrl': baseUrl.trim()};
  }
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

  IconData get icon {
    switch (id) {
      case 'openai':
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
      return 'No models discovered yet';
    }
    if (availableModelCount == modelCount) {
      return '$modelCount models ready';
    }
    return '$availableModelCount of $modelCount models ready';
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

  String get createdAtLabel => _formatTimestamp(createdAt);

  String get totalTokensLabel => _formatNumber(totalTokens);

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get triggerLabel => triggerSource.ifEmpty('web');

  String get modelLabel => model.ifEmpty('Model pending');

  Duration? get duration => completedAt?.difference(createdAt);

  String get durationLabel =>
      completedAt == null ? 'In progress' : _formatElapsed(duration!);

  Color get statusColor {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
      case 'error':
        return _danger;
      case 'running':
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
  });

  factory TokenUsageSnapshot.fromJson(Map<dynamic, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    return TokenUsageSnapshot(
      totalTokens: _asInt(totals['totalTokens']),
      totalRuns: _asInt(totals['totalRuns']),
      avgTokensPerRun: _asInt(totals['avgTokensPerRun']),
      last7DaysTokens: _asInt(totals['last7DaysTokens']),
      last7DaysRuns: _asInt(totals['last7DaysRuns']),
    );
  }

  final int totalTokens;
  final int totalRuns;
  final int avgTokensPerRun;
  final int last7DaysTokens;
  final int last7DaysRuns;

  String get totalTokensLabel => _formatNumber(totalTokens);
  String get totalRunsLabel => _formatNumber(totalRuns);
  String get avgTokensPerRunLabel => _formatNumber(avgTokensPerRun);
  String get last7DaysTokensLabel => _formatNumber(last7DaysTokens);
  String get last7DaysRunsLabel => _formatNumber(last7DaysRuns);
}

class UpdateStatusSnapshot {
  const UpdateStatusSnapshot({
    this.state = 'idle',
    this.progress = 0,
    this.message = 'No update running',
    this.releaseChannel = 'stable',
    this.allowSelfUpdate = true,
    this.deploymentMode = 'self_hosted',
    this.deploymentProfile = 'private',
    this.targetBranch,
    this.npmDistTag,
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
      message: json['message']?.toString() ?? 'No update running',
      releaseChannel: json['releaseChannel']?.toString() ?? 'stable',
      allowSelfUpdate: json['allowSelfUpdate'] != false,
      deploymentMode: json['deploymentMode']?.toString() ?? 'self_hosted',
      deploymentProfile: json['deploymentProfile']?.toString() ?? 'private',
      targetBranch: json['targetBranch']?.toString(),
      npmDistTag: json['npmDistTag']?.toString(),
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
  final String deploymentProfile;
  final String? targetBranch;
  final String? npmDistTag;
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
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return 'Idle';
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

  String get deploymentProfileLabel =>
      deploymentProfile.toLowerCase() == 'prod' ? 'Production' : 'Private';

  String get runtimeModeLabel => deploymentProfile.toLowerCase() == 'prod'
      ? 'Cloud runtime'
      : 'Trusted host runtime';

  String get runtimeValidationLabel =>
      runtimeValidationReady ? 'Runtime ready' : 'Runtime setup required';

  Color get runtimeValidationColor =>
      runtimeValidationReady ? _success : _danger;

  String get versionLine {
    final before = versionBefore?.ifEmpty('—') ?? '—';
    final after = versionAfter?.ifEmpty('—') ?? '—';
    final updateVersion = after == '—' ? before : '$before -> $after';
    final branch = targetBranch?.trim().isNotEmpty == true
        ? ' | Branch: $targetBranch'
        : '';
    final npm = npmDistTag?.trim().isNotEmpty == true
        ? ' | npm: $npmDistTag'
        : '';
    final installed = installedVersion == null
        ? ''
        : ' | Installed: $installedVersion';
    final backend = backendVersion == null ? '' : ' | Runtime: $backendVersion';
    return 'Profile: $deploymentProfileLabel | Channel: $releaseChannelLabel$branch$npm | Update Version: $updateVersion$installed$backend';
  }

  String get logsText =>
      logs.isEmpty ? 'Waiting for update job output…' : logs.join('\n');
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

  String get clipboardLine => '[$timeLabel][$source] $message';

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
        return 'Server';
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
      name: json['name']?.toString() ?? 'Skill',
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
      name: json['name']?.toString() ?? 'Skill',
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

  String get statusLabel => _titleCase(effectiveStatus.replaceAll('_', ' '));
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
        return 'Setup Required';
      case 'not_connected':
        return 'Not Connected';
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
  final OfficialIntegrationMemoryCoverage memoryCoverage;

  bool get isExpired => status == 'expired';

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get accessModeLabel {
    switch (accessMode) {
      case 'read_only':
        return 'Read Only';
      default:
        return 'Read / Write';
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
      label: json['label']?.toString() ?? 'Integration',
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

  String get statusLabel => _titleCase(effectiveStatus.replaceAll('_', ' '));
}

class SkillDocument {
  const SkillDocument({required this.name, required this.content});

  factory SkillDocument.fromJson(Map<dynamic, dynamic> json) {
    return SkillDocument(
      name: json['name']?.toString() ?? 'Skill',
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
    );
  }

  final String assistantBehaviorNotes;
  final List<String> dailyLogs;
  final Map<String, String> apiKeys;
  final Map<String, dynamic> coreEntries;

  int get behaviorNotesLength => assistantBehaviorNotes.length;
  int get dailyLogCount => dailyLogs.length;
  int get apiKeyCount => apiKeys.length;
  int get coreCount => coreEntries.length;
}

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<dynamic, dynamic> json) {
    return MemoryItem(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('memory') ?? 'memory',
      importance: _asInt(json['importance']),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final String id;
  final String content;
  final String category;
  final int importance;
  final DateTime createdAt;

  String get createdAtLabel => _formatTimestamp(createdAt);
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
          json['title']?.toString().ifEmpty('Conversation') ?? 'Conversation',
      preview: raw.ifEmpty('No summary available.'),
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
    required this.nextRun,
    required this.prompt,
    required this.model,
    required this.enabled,
    required this.lastRun,
    required this.taskType,
    required this.widgetId,
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
    return TaskItem(
      id: _asInt(json['id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString() ?? 'Task',
      triggerType: json['triggerType']?.toString() ?? 'schedule',
      triggerSummary: triggerSummary.trim().isEmpty
          ? 'Task trigger'
          : triggerSummary,
      triggerConfig: triggerConfig,
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
      taskType:
          json['taskType']?.toString().ifEmpty(
            json['task_type']?.toString() ?? 'agent_prompt',
          ) ??
          'agent_prompt',
      widgetId:
          json['widgetId']?.toString().ifEmpty(
            taskConfig['widgetId']?.toString() ?? '',
          ) ??
          '',
    );
  }

  final int id;
  final String? agentId;
  final String name;
  final String triggerType;
  final String triggerSummary;
  final Map<String, dynamic> triggerConfig;
  final DateTime? nextRun;
  final String prompt;
  final String model;
  final bool enabled;
  final DateTime? lastRun;
  final String taskType;
  final String widgetId;

  String get scheduleLabel =>
      triggerSummary.trim().isEmpty ? 'Task trigger' : triggerSummary;
  String get lastRunLabel => lastRun == null ? '' : _formatTimestamp(lastRun!);
  bool get hasModelOverride => model.trim().isNotEmpty;
  bool get isWidgetRefresh => taskType == 'widget_refresh';
}

class WidgetSnapshotItem {
  const WidgetSnapshotItem({
    required this.id,
    required this.widgetId,
    required this.payload,
    required this.generatedAt,
    required this.sourceRunId,
    required this.status,
  });

  factory WidgetSnapshotItem.fromJson(Map<dynamic, dynamic> json) {
    return WidgetSnapshotItem(
      id: _asInt(json['id']),
      widgetId:
          json['widgetId']?.toString() ?? json['widget_id']?.toString() ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
      generatedAt: _parseOptionalTimestamp(
        json['generatedAt']?.toString() ?? json['generated_at']?.toString(),
      ),
      sourceRunId:
          json['sourceRunId']?.toString() ?? json['source_run_id']?.toString(),
      status: json['status']?.toString().ifEmpty('ready') ?? 'ready',
    );
  }

  final int id;
  final String widgetId;
  final Map<String, dynamic> payload;
  final DateTime? generatedAt;
  final String? sourceRunId;
  final String status;

  String get title =>
      payload['title']?.toString().ifEmpty('Untitled widget') ??
      'Untitled widget';
  String get kicker => payload['kicker']?.toString() ?? '';
  String get subtitle => payload['subtitle']?.toString() ?? '';
  String get body => payload['body']?.toString() ?? '';
  String get metric => payload['metric']?.toString() ?? '';
  String get metricLabel => payload['metricLabel']?.toString() ?? '';
  String get secondaryMetric => payload['secondaryMetric']?.toString() ?? '';
  String get secondaryLabel => payload['secondaryLabel']?.toString() ?? '';
  String get tertiaryMetric => payload['tertiaryMetric']?.toString() ?? '';
  String get tertiaryLabel => payload['tertiaryLabel']?.toString() ?? '';
  String get template => payload['template']?.toString() ?? '';
  String get layoutVariant => payload['layoutVariant']?.toString() ?? '';
  String get deepLink => payload['deepLink']?.toString() ?? '';
  String get iconToken => payload['iconToken']?.toString() ?? '';
  String get accentToken => payload['accentToken']?.toString() ?? '';
  String get backgroundToken => payload['backgroundToken']?.toString() ?? '';
  String get surfaceColor => payload['surfaceColor']?.toString() ?? '';

  Map<String, dynamic>? get trend {
    final raw = payload['trend'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Map<String, dynamic>? get progress {
    final raw = payload['progress'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  List<Map<String, dynamic>> get rows => _jsonMapList(payload['rows']);
  List<String> get chips =>
      (payload['chips'] as List?)
          ?.map((chip) => chip?.toString() ?? '')
          .where((chip) => chip.trim().isNotEmpty)
          .toList(growable: false) ??
      const <String>[];

  String get generatedAtLabel =>
      generatedAt == null ? 'No refresh yet' : _formatTimestamp(generatedAt!);
}

class AiWidgetItem {
  const AiWidgetItem({
    required this.id,
    required this.userId,
    required this.agentId,
    required this.name,
    required this.widgetKind,
    required this.systemKey,
    required this.isSystem,
    required this.template,
    required this.layoutVariant,
    required this.definition,
    required this.refreshCron,
    required this.enabled,
    required this.scheduledTaskId,
    required this.lastSnapshotAt,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    required this.nextRefresh,
    required this.latestSnapshot,
    required this.tasks,
  });

  factory AiWidgetItem.fromJson(Map<dynamic, dynamic> json) {
    return AiWidgetItem(
      id: json['id']?.toString() ?? '',
      userId: _asInt(json['userId'] ?? json['user_id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString().ifEmpty('Widget') ?? 'Widget',
      widgetKind:
          json['widgetKind']?.toString().ifEmpty(
            json['widget_kind']?.toString() ?? 'custom',
          ) ??
          'custom',
      systemKey:
          json['systemKey']?.toString() ?? json['system_key']?.toString(),
      isSystem: json['isSystem'] == true || json['is_system'] == true,
      template: json['template']?.toString().ifEmpty('summary') ?? 'summary',
      layoutVariant:
          json['layoutVariant']?.toString().ifEmpty(
            json['layout_variant']?.toString() ?? 'stack',
          ) ??
          'stack',
      definition: json['definition'] is Map
          ? Map<String, dynamic>.from(json['definition'] as Map)
          : (json['definition_json'] is Map
                ? Map<String, dynamic>.from(json['definition_json'] as Map)
                : const <String, dynamic>{}),
      refreshCron:
          json['refreshCron']?.toString().ifEmpty(
            json['refresh_cron']?.toString() ?? '',
          ) ??
          '',
      enabled: json['enabled'] != false,
      scheduledTaskId: _asInt(
        json['scheduledTaskId'] ?? json['scheduled_task_id'],
      ),
      lastSnapshotAt: _parseOptionalTimestamp(
        json['lastSnapshotAt']?.toString() ??
            json['last_snapshot_at']?.toString(),
      ),
      lastError:
          json['lastError']?.toString() ?? json['last_error']?.toString(),
      createdAt: _parseOptionalTimestamp(
        json['createdAt']?.toString() ?? json['created_at']?.toString(),
      ),
      updatedAt: _parseOptionalTimestamp(
        json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
      ),
      nextRefresh: _parseOptionalTimestamp(
        json['nextRefresh']?.toString() ?? json['next_refresh']?.toString(),
      ),
      latestSnapshot: json['latestSnapshot'] is Map
          ? WidgetSnapshotItem.fromJson(
              Map<String, dynamic>.from(json['latestSnapshot'] as Map),
            )
          : null,
      tasks: json['tasks'] is List
          ? (json['tasks'] as List)
                .whereType<Map<dynamic, dynamic>>()
                .map((m) => TaskItem.fromJson(m))
                .toList()
          : const <TaskItem>[],
    );
  }

  final String id;
  final int userId;
  final String? agentId;
  final String name;
  final String widgetKind;
  final String? systemKey;
  final bool isSystem;
  final String template;
  final String layoutVariant;
  final Map<String, dynamic> definition;
  final String refreshCron;
  final bool enabled;
  final int scheduledTaskId;
  final DateTime? lastSnapshotAt;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? nextRefresh;
  final WidgetSnapshotItem? latestSnapshot;
  final List<TaskItem> tasks;

  bool get hasSnapshot => latestSnapshot != null;
  bool get hasError => (lastError ?? '').trim().isNotEmpty;
  String get prompt => definition['prompt']?.toString() ?? '';
  String get nextRefreshLabel => nextRefresh == null
      ? 'Next refresh unknown'
      : _formatTimestamp(nextRefresh!);
  String get lastSnapshotLabel => lastSnapshotAt == null
      ? 'No snapshot yet'
      : _formatTimestamp(lastSnapshotAt!);
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
  });

  factory McpServerItem.fromJson(Map<dynamic, dynamic> json) {
    return McpServerItem(
      id: _asInt(json['id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString() ?? 'MCP Server',
      command: json['command']?.toString() ?? '',
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const <String, dynamic>{},
      enabled: json['enabled'] == true,
      status: json['status']?.toString().ifEmpty('stopped') ?? 'stopped',
      toolCount: _asInt(json['toolCount']),
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

  String get authMethodLabel {
    final auth = _jsonMap(config['auth']);
    final type = auth['type']?.toString().ifEmpty('none') ?? 'none';
    switch (type) {
      case 'bearer':
        return 'Bearer token';
      case 'oauth':
        return 'OAuth';
      default:
        return 'No auth';
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
          clientBrowserLabel != 'Unknown browser')
        clientBrowserLabel,
    ];
    return parts.join(' · ').ifEmpty('Unknown device');
  }

  String get locationSummary {
    final parts = <String>[
      if (location.trim().isNotEmpty) location.trim(),
      if (ipAddress.trim().isNotEmpty) ipAddress.trim(),
    ];
    return parts.join(' · ').ifEmpty('Unknown location');
  }

  String get lastSeenLabel =>
      lastSeenAt == null ? 'Not recorded' : _formatTimestamp(lastSeenAt!);
  String get createdLabel =>
      createdAt == null ? 'Not recorded' : _formatTimestamp(createdAt!);
  String get expiresLabel =>
      expiresAt == null ? 'Session cookie' : _formatTimestamp(expiresAt!);
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
      return const _SessionClientInfo(
        platformLabel: 'Unknown device',
        browserLabel: 'Unknown browser',
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
        'CLI session',
      _ => 'Unknown device',
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
      _ => 'Unknown browser',
    };

    final deviceClass = switch (true) {
      _ when platformLabel == 'CLI session' => _SessionDeviceClass.server,
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
      linkedAt == null ? 'Linked recently' : _formatTimestamp(linkedAt!);
  String get lastUsedLabel =>
      lastUsedAt == null ? 'Not used yet' : _formatTimestamp(lastUsedAt!);
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
          json['label']?.toString().ifEmpty('Unknown device') ??
          'Unknown device',
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
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
    return label.contains('subagent') || label.contains('helper');
  }

  bool get isBrowserRelated {
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
    return label.contains('browser') ||
        label.contains('page') ||
        label.contains('screenshot');
  }

  bool get isMessagingRelated {
    final label = '${type.toLowerCase()} ${toolName.toLowerCase()}';
    return label.contains('message') ||
        label.contains('telegram') ||
        label.contains('discord') ||
        label.contains('whatsapp') ||
        label.contains('slack');
  }

  bool get isWebRelated => isBrowserRelated || isMessagingRelated;

  String get laneLabel {
    if (isPlanningRelated) {
      return 'Planning';
    }
    if (isHelperRelated) {
      return 'Helper';
    }
    if (isWebRelated) {
      return 'Web';
    }
    if (type == 'verification') {
      return 'Verification';
    }
    return 'Execution';
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
