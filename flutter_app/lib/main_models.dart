part of 'main.dart';

const List<MessagingPlatformDescriptor> messagingPlatforms =
    <MessagingPlatformDescriptor>[
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
      ),
      MessagingPlatformDescriptor(
        id: 'discord',
        label: 'Discord',
        subtitle: 'Bot token and server/channel access',
        accent: Color(0xFF5865F2),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.sports_esports_rounded,
      ),
      MessagingPlatformDescriptor(
        id: 'telnyx',
        label: 'Telnyx Voice',
        subtitle: 'Inbound and outbound calling',
        accent: Color(0xFF00C8A0),
        connectMethod: MessagingConnectMethod.config,
        icon: Icons.call_rounded,
      ),
    ];

enum MessagingConnectMethod { qr, config }

class MessagingPlatformDescriptor {
  const MessagingPlatformDescriptor({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.connectMethod,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color accent;
  final MessagingConnectMethod connectMethod;
  final IconData icon;
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
    for (final key in <String>['phoneNumber', 'tag', 'username']) {
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
    required this.durationMs,
    required this.chunkCount,
  });

  factory RecordingSourceItem.fromJson(Map<dynamic, dynamic> json) {
    return RecordingSourceItem(
      sourceKey: json['sourceKey']?.toString() ?? '',
      sourceKind: json['sourceKind']?.toString() ?? '',
      mediaKind: json['mediaKind']?.toString() ?? '',
      durationMs: _asInt(json['durationMs']),
      chunkCount: _asInt(json['chunkCount']),
    );
  }

  final String sourceKey;
  final String sourceKind;
  final String mediaKind;
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
    required this.apiKey,
    required this.baseUrl,
  });

  factory AiProviderConfig.empty(String id) {
    return AiProviderConfig(
      id: id,
      enabled: true,
      apiKey: '',
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
      apiKey: map['apiKey']?.toString() ?? '',
      baseUrl:
          map['baseUrl']?.toString() ??
          (id == 'ollama' ? 'http://localhost:11434' : ''),
    );
  }

  final String id;
  final bool enabled;
  final String apiKey;
  final String baseUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'apiKey': apiKey.trim(),
      'baseUrl': baseUrl.trim(),
    };
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
    required this.hasStoredApiKey,
    required this.hasEnvironmentApiKey,
    required this.usesEnvironmentApiKey,
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
      hasStoredApiKey: json['hasStoredApiKey'] == true,
      hasEnvironmentApiKey: json['hasEnvironmentApiKey'] == true,
      usesEnvironmentApiKey: json['usesEnvironmentApiKey'] == true,
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
  final bool hasStoredApiKey;
  final bool hasEnvironmentApiKey;
  final bool usesEnvironmentApiKey;
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
      case 'stored_key':
      case 'env_key':
      case 'local':
        return _success;
      case 'disabled':
        return _textSecondary;
      case 'needs_key':
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
    this.versionBefore,
    this.versionAfter,
    this.backendVersion,
    this.installedVersion,
    this.changelog = const <String>[],
    this.logs = const <String>[],
  });

  factory UpdateStatusSnapshot.fromJson(Map<dynamic, dynamic> json) {
    return UpdateStatusSnapshot(
      state: json['state']?.toString() ?? 'idle',
      progress: _asInt(json['progress']).clamp(0, 100),
      message: json['message']?.toString() ?? 'No update running',
      versionBefore: json['versionBefore']?.toString(),
      versionAfter: json['versionAfter']?.toString(),
      backendVersion: json['backendVersion']?.toString(),
      installedVersion:
          json['installedVersion']?.toString() ??
          json['packageVersion']?.toString(),
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
  final String? versionBefore;
  final String? versionAfter;
  final String? backendVersion;
  final String? installedVersion;
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

  String get versionLine {
    final before = versionBefore?.ifEmpty('—') ?? '—';
    final after = versionAfter?.ifEmpty('—') ?? '—';
    final updateVersion = after == '—' ? before : '$before -> $after';
    final installed = installedVersion == null
        ? ''
        : ' | Installed: $installedVersion';
    final backend = backendVersion == null ? '' : ' | Runtime: $backendVersion';
    return 'Update Version: $updateVersion$installed$backend';
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
    this.soul = '',
    this.dailyLogs = const <String>[],
    this.apiKeys = const <String, String>{},
    this.coreEntries = const <String, dynamic>{},
  });

  factory MemoryOverview.fromJson(Map<dynamic, dynamic> json) {
    final apiKeysRaw = json['apiKeys'];
    final coreRaw = json['coreMemory'];
    return MemoryOverview(
      soul: json['soul']?.toString() ?? '',
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

  final String soul;
  final List<String> dailyLogs;
  final Map<String, String> apiKeys;
  final Map<String, dynamic> coreEntries;

  int get soulLength => soul.length;
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
      id: _asInt(json['id']),
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString().ifEmpty('memory') ?? 'memory',
      importance: _asInt(json['importance']),
      createdAt: _parseTimestamp(json['created_at']?.toString()),
    );
  }

  final int id;
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
    required this.name,
    required this.cronExpression,
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
      name: json['name']?.toString() ?? 'Task',
      cronExpression: json['cronExpression']?.toString() ?? '',
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
  final String name;
  final String cronExpression;
  final String prompt;
  final String model;
  final bool enabled;
  final DateTime? lastRun;

  String get lastRunLabel => lastRun == null ? '' : _formatTimestamp(lastRun!);
  bool get hasModelOverride => model.trim().isNotEmpty;
}

class McpServerItem {
  const McpServerItem({
    required this.id,
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

class ActiveRunState {
  const ActiveRunState({
    required this.runId,
    required this.title,
    required this.model,
    required this.triggerSource,
    required this.phase,
    required this.iteration,
  });

  factory ActiveRunState.pending(String task) {
    return ActiveRunState(
      runId: 'pending',
      title: task,
      model: '',
      triggerSource: 'web',
      phase: 'Queued',
      iteration: 0,
    );
  }

  final String runId;
  final String title;
  final String model;
  final String triggerSource;
  final String phase;
  final int iteration;

  ActiveRunState copyWith({
    String? runId,
    String? title,
    String? model,
    String? triggerSource,
    String? phase,
    int? iteration,
  }) {
    return ActiveRunState(
      runId: runId ?? this.runId,
      title: title ?? this.title,
      model: model ?? this.model,
      triggerSource: triggerSource ?? this.triggerSource,
      phase: phase ?? this.phase,
      iteration: iteration ?? this.iteration,
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
