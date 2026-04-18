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
    id: 'telnyx',
    label: 'Telnyx Voice',
    subtitle: 'Inbound and outbound calling',
    accent: Color(0xFF00C8A0),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.call_rounded,
  ),
  MessagingPlatformDescriptor(
    id: 'waveshare_wearable',
    label: 'NeoOS Wearable',
    subtitle: 'Pairing and connected-device visibility',
    accent: Color(0xFF1D4ED8),
    connectMethod: MessagingConnectMethod.config,
    icon: Icons.watch_rounded,
    configFields: <MessagingConfigField>[
      MessagingConfigField(key: 'deviceLabel', label: 'Device Label'),
      MessagingConfigField(key: 'pairingCode', label: 'Pairing Code'),
    ],
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
  });

  final String key;
  final String label;
  final MessagingConfigFieldKind kind;
  final bool obscure;
  final String? defaultValue;
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
  });

  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final MessagingConnectMethod connectMethod;
  final IconData icon;
  final List<MessagingConfigField> configFields;

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
    final metadata = _decodeMaybeJson(json['metadata']);
    return MessagingMessage(
      platform: json['platform']?.toString() ?? 'web',
      content: json['content']?.toString() ?? '',
      createdAt: _parseTimestamp(json['created_at']?.toString()),
      outgoing: json['role']?.toString() == 'assistant',
      chatId: json['platform_chat_id']?.toString(),
      sender: metadata['sender']?.toString(),
      senderName: metadata['senderName']?.toString(),
      target: json['platform_chat_id']?.toString(),
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
              .where((item) => item.entry.isNotEmpty)
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
  const QuickAllowSuggestion({required this.label, required this.entry});

  factory QuickAllowSuggestion.fromJson(
    String platform,
    Map<String, dynamic> json,
  ) {
    final prefixedId = json['prefixedId']?.toString().trim() ?? '';
    return QuickAllowSuggestion(
      label:
          json['label']?.toString().ifEmpty('Allow sender') ?? 'Allow sender',
      entry: _normalizeSuggestedWhitelistEntry(platform, prefixedId),
    );
  }

  final String label;
  final String entry;
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
      sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(RecordingSourceItem.fromJson)
          .toList(),
      transcriptSegments:
          (json['transcriptSegments'] as List<dynamic>? ?? const <dynamic>[])
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

class VoiceAssistantLiveState {
  VoiceAssistantLiveState({
    this.sessionId = '',
    this.runtimeMode = 'legacy',
    this.provider = 'openai',
    this.model = '',
    this.voice = '',
    this.state = 'idle',
    this.partialTranscript = '',
    this.finalTranscript = '',
    this.assistantText = '',
    this.audioMimeType = 'audio/mpeg',
    Uint8List? audioBytes,
    this.error,
  }) : audioBytes = audioBytes ?? Uint8List(0);

  final String sessionId;
  final String runtimeMode;
  final String provider;
  final String model;
  final String voice;
  final String state;
  final String partialTranscript;
  final String finalTranscript;
  final String assistantText;
  final String audioMimeType;
  final Uint8List audioBytes;
  final String? error;

  bool get hasActiveSession => sessionId.trim().isNotEmpty;
  bool get isLive => runtimeMode == 'live';
  bool get isListening => state == 'listening';
  bool get isBusy =>
      state == 'transcribing' || state == 'thinking' || state == 'speaking';

  VoiceAssistantLiveState copyWith({
    String? sessionId,
    String? runtimeMode,
    String? provider,
    String? model,
    String? voice,
    String? state,
    String? partialTranscript,
    String? finalTranscript,
    String? assistantText,
    String? audioMimeType,
    Uint8List? audioBytes,
    String? error,
    bool clearError = false,
  }) {
    return VoiceAssistantLiveState(
      sessionId: sessionId ?? this.sessionId,
      runtimeMode: runtimeMode ?? this.runtimeMode,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      state: state ?? this.state,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      assistantText: assistantText ?? this.assistantText,
      audioMimeType: audioMimeType ?? this.audioMimeType,
      audioBytes: audioBytes ?? this.audioBytes,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RunDetailSnapshot {
  const RunDetailSnapshot({
    required this.run,
    required this.steps,
    required this.response,
  });

  factory RunDetailSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return RunDetailSnapshot(
      run: RunSummary.fromJson(_jsonMap(json['run'])),
      steps: (json['steps'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(RunStepItem.fromJson)
          .toList(),
      response: json['response']?.toString() ?? '',
    );
  }

  final RunSummary run;
  final List<RunStepItem> steps;
  final String response;

  int get completedTools => steps
      .where((step) => step.toolName.isNotEmpty && step.status == 'completed')
      .length;

  int get failedTools => steps.where((step) => step.status == 'failed').length;

  int get helperCount => steps.where((step) {
    final label = '${step.type} ${step.toolName}'.toLowerCase();
    return label.contains('subagent') || label.contains('helper');
  }).length;
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

Map<String, dynamic> _decodeMaybeJson(dynamic value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  return const <String, dynamic>{};
}

class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.content,
    required this.platform,
    required this.createdAt,
    this.senderName,
    this.transient = false,
  });

  factory ChatEntry.fromJson(Map<dynamic, dynamic> json) {
    return ChatEntry(
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'web',
      senderName: json['sender_name']?.toString(),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final String role;
  final String content;
  final String platform;
  final String? senderName;
  final DateTime createdAt;
  final bool transient;

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
      delegateTargets:
          (json['delegateTargets'] as List<dynamic>? ??
                  json['delegate_targets'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .where((id) => id.isNotEmpty)
              .toList(),
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
  });

  factory RunSummary.fromJson(Map<dynamic, dynamic> json) {
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
      runtimeValidationIssues:
          (_jsonMap(json['runtimeValidation'])['issues'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      runtimeAcceleration: _jsonMap(
        _jsonMap(json['runtimeValidation'])['vm'],
      )['acceleration']?.toString(),
      changelog: (json['changelog'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      logs: (json['logs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
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
      ? 'Per-user isolated VM runtime'
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
  });

  factory LogEntry.fromJson(Map<dynamic, dynamic> json) {
    return LogEntry(
      type: json['type']?.toString() ?? 'log',
      message: json['message']?.toString() ?? '',
      timestamp: _parseTimestamp(json['timestamp']?.toString()),
    );
  }

  final String type;
  final String message;
  final DateTime timestamp;

  String get timeLabel => _formatTimeOnly(timestamp);

  String get clipboardLine => '[$timeLabel] $message';

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
    );
  }

  final String id;
  final String label;
  final String? description;
  final OfficialIntegrationConnectionStatus connection;
  final List<OfficialIntegrationAccountItem> accounts;
  final int availableToolCount;

  bool get isConnected => connection.connected;
}

class OfficialIntegrationEnvStatus {
  const OfficialIntegrationEnvStatus({
    required this.configured,
    required this.missing,
    required this.summary,
  });

  factory OfficialIntegrationEnvStatus.fromJson(Map<dynamic, dynamic> json) {
    final missingRaw = json['missing'];
    return OfficialIntegrationEnvStatus(
      configured: json['configured'] == true,
      missing: missingRaw is List
          ? missingRaw.map((item) => item.toString()).toList()
          : const <String>[],
      summary: json['summary']?.toString() ?? '',
    );
  }

  final bool configured;
  final List<String> missing;
  final String summary;
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
      default:
        return _titleCase(status.replaceAll('_', ' '));
    }
  }
}

class OfficialIntegrationAccountItem {
  const OfficialIntegrationAccountItem({
    required this.id,
    required this.status,
    required this.connected,
    this.accountEmail,
    this.lastConnectedAt,
    this.accessMode = 'read_write',
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
    );
  }

  final int id;
  final String status;
  final bool connected;
  final String? accountEmail;
  final DateTime? lastConnectedAt;
  final String accessMode;

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

  bool get isConnected => connection.connected;
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
      dailyLogs: (json['dailyLogs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
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

class SchedulerTask {
  const SchedulerTask({
    required this.id,
    required this.agentId,
    required this.name,
    required this.cronExpression,
    required this.runAt,
    required this.oneTime,
    required this.prompt,
    required this.model,
    required this.enabled,
    required this.lastRun,
  });

  factory SchedulerTask.fromJson(Map<dynamic, dynamic> json) {
    final config = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    return SchedulerTask(
      id: _asInt(json['id']),
      agentId: json['agentId']?.toString() ?? json['agent_id']?.toString(),
      name: json['name']?.toString() ?? 'Task',
      cronExpression: json['cronExpression']?.toString() ?? '',
      runAt: _parseOptionalTimestamp(json['runAt']?.toString()),
      oneTime: json['oneTime'] == true,
      prompt:
          json['prompt']?.toString().ifEmpty(
            config['prompt']?.toString() ?? '',
          ) ??
          '',
      model:
          json['model']?.toString().ifEmpty(
            config['model']?.toString() ?? '',
          ) ??
          '',
      enabled: json['enabled'] != false,
      lastRun: _parseOptionalTimestamp(json['lastRun']?.toString()),
    );
  }

  final int id;
  final String? agentId;
  final String name;
  final String cronExpression;
  final DateTime? runAt;
  final bool oneTime;
  final String prompt;
  final String model;
  final bool enabled;
  final DateTime? lastRun;

  String get scheduleLabel => oneTime
      ? (runAt == null
            ? 'One-time run'
            : 'One-time at ${_formatTimestamp(runAt!)}')
      : cronExpression;
  String get lastRunLabel => lastRun == null ? '' : _formatTimestamp(lastRun!);
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

  _SessionClientInfo get clientInfo => _SessionClientInfo.parse(userAgent);

  IconData get deviceIcon => switch (clientInfo.deviceClass) {
    _SessionDeviceClass.mobile => Icons.smartphone_rounded,
    _SessionDeviceClass.tablet => Icons.tablet_mac_rounded,
    _SessionDeviceClass.desktop => Icons.laptop_mac_rounded,
    _SessionDeviceClass.server => Icons.dns_outlined,
    _SessionDeviceClass.unknown => Icons.devices_other_rounded,
  };

  String get clientLabel {
    final parts = <String>[
      clientInfo.platformLabel,
      if (clientInfo.browserLabel.isNotEmpty &&
          clientInfo.browserLabel != 'Unknown browser')
        clientInfo.browserLabel,
    ];
    return parts.join(' · ').ifEmpty('Unknown device') ?? 'Unknown device';
  }

  String get locationSummary {
    final parts = <String>[
      if (location.trim().isNotEmpty) location.trim(),
      if (ipAddress.trim().isNotEmpty) ipAddress.trim(),
    ];
    return parts.join(' · ').ifEmpty('Unknown location') ?? 'Unknown location';
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
      _ when lower.contains('mac os x') || lower.contains('macintosh') => 'macOS',
      _ when lower.contains('windows nt') => 'Windows',
      _ when lower.contains('linux') => 'Linux',
      _ when lower.contains('x11') => 'Linux',
      _ when lower.contains('curl/') ||
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
      _ when lower.contains('chrome/') ||
          lower.contains('crios/') ||
          lower.contains('chromium/') =>
        'Chrome',
      _ when lower.contains('safari/') && lower.contains('version/') => 'Safari',
      _ when lower.contains('curl/') => 'curl',
      _ when lower.contains('wget/') => 'wget',
      _ when lower.contains('httpie/') => 'HTTPie',
      _ => 'Unknown browser',
    };

    final deviceClass = switch (true) {
      _ when platformLabel == 'CLI session' => _SessionDeviceClass.server,
      _ when isTablet => _SessionDeviceClass.tablet,
      _ when isMobile => _SessionDeviceClass.mobile,
      _ when platformLabel == 'macOS' ||
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
}
