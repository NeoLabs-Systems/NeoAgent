part of 'main.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastToolCount = 0;
  String _lastStream = '';
  bool _isSendingChatMessage = false;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    widget.controller.addListener(_consumeQueuedDraft);
    _consumeQueuedDraft();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_consumeQueuedDraft);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _consumeQueuedDraft() {
    final draft = widget.controller.takePendingChatDraft();
    if (draft == null || draft.isEmpty) {
      return;
    }
    _composerController
      ..text = draft
      ..selection = TextSelection.collapsed(offset: draft.length);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final messages = controller.visibleChatMessages;
    if (_lastMessageCount != messages.length ||
        _lastToolCount != controller.toolEvents.length ||
        _lastStream != controller.streamingAssistant) {
      _lastMessageCount = messages.length;
      _lastToolCount = controller.toolEvents.length;
      _lastStream = controller.streamingAssistant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: _pagePadding(context),
            children: <Widget>[
              _PageTitle(
                title: 'Chat',
                subtitle: 'Live agent chat with tool and stream status.',
                trailing: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => controller.setSelectedSection(
                        AppSection.voiceAssistant,
                      ),
                      icon: Icon(Icons.call),
                      label: Text('Call'),
                    ),
                    _MetaPill(
                      label: controller.modelIndicator,
                      icon: Icons.memory_outlined,
                    ),
                    _MetaPill(
                      label: 'Agent: ${controller.activeAgentLabel}',
                      icon: Icons.smart_toy_outlined,
                    ),
                  ],
                ),
              ),
              if (controller.errorMessage != null) ...<Widget>[
                _InlineError(message: controller.errorMessage!),
                const SizedBox(height: 16),
              ],
              if (controller.activeRun != null ||
                  controller.toolEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RunStatusPanel(
                    run: controller.activeRun,
                    tools: controller.toolEvents,
                  ),
                ),
              if (messages.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                    child: _EmptyState(
                      title: 'How can I help?',
                      subtitle:
                          'Runs, tools, memory, scheduling, skills, and MCP are all available here.',
                    ),
                  ),
                )
              else
                ...messages.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ChatBubble(
                      entry: entry,
                      onLoadRunDetail: controller.fetchRunDetail,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: _bgPrimary,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                decoration: BoxDecoration(
                  color: _bgTertiary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: controller.chatComposerHint,
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => controller.setSelectedSection(
                        AppSection.voiceAssistant,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(46, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(Icons.call_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSendingChatMessage
                          ? null
                          : () async {
                              final task = _composerController.text;
                              if (task.trim().isEmpty ||
                                  _isSendingChatMessage) {
                                return;
                              }
                              setState(() {
                                _isSendingChatMessage = true;
                              });
                              _composerController.clear();
                              try {
                                await controller.sendMessage(task);
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isSendingChatMessage = false;
                                  });
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(46, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(
                        controller.hasLiveRun
                            ? Icons.alt_route_rounded
                            : Icons.north_east_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      controller.chatStatusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      controller.hasLiveRun
                          ? 'Steering mode'
                          : controller.modelIndicator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessagingPanel extends StatefulWidget {
  const MessagingPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MessagingPanel> createState() => _MessagingPanelState();
}

MessagingPlatformDescriptor? _messagingPlatformById(String id) {
  for (final platform in messagingPlatforms) {
    if (platform.id == id) return platform;
  }
  return null;
}

class _MessagingPanelState extends State<MessagingPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final groups = [
      const (
        'Text & Chat',
        'Personal channels and direct support surfaces.',
        [
          'whatsapp',
          'signal',
          'imessage',
          'bluebubbles',
          'line',
          'zalo_personal',
        ],
      ),
      const (
        'Community & ChatOps',
        'Team spaces, rooms, channels, and live communities.',
        [
          'discord',
          'telegram',
          'slack',
          'google_chat',
          'teams',
          'matrix',
          'mattermost',
          'irc',
          'twitch',
        ],
      ),
      const (
        'Configurable Webhooks',
        'Bridge any provider that can post and receive webhook payloads.',
        [
          'feishu',
          'nextcloud_talk',
          'nostr',
          'synology_chat',
          'tlon',
          'zalo',
          'wechat',
          'webchat',
        ],
      ),
      const (
        'Hardware Bridges',
        'Local device bridges and TCP-connected integrations.',
        [
          'meshtastic',
        ],
      ),
      const ('Voice', 'Telephony integrations.', ['telnyx']),
    ];
    final query = _searchController.text.trim().toLowerCase();
    final counts = _MessagingStatusCounts.from(controller.messagingStatuses);
    final hasMatches = _hasMessagingMatches(controller, groups, query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageTitle(
          title: 'Messaging',
          subtitle:
              'Connect channels, limit who can reach the agent, and monitor activity.',
          trailing: OutlinedButton.icon(
            onPressed: controller.refreshMessaging,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh'),
          ),
        ),
        const SizedBox(height: 18),
        _MessagingOverviewStrip(counts: counts),
        const SizedBox(height: 16),
        _MessagingToolbar(
          controller: _searchController,
          selectedFilter: _statusFilter,
          onFilterChanged: (value) => setState(() => _statusFilter = value),
          counts: counts,
        ),
        if (controller.pendingMessagingQr != null) ...[
          const SizedBox(height: 18),
          _MessagingQrPanel(qrState: controller.pendingMessagingQr!),
        ],
        const SizedBox(height: 18),
        for (final group in groups)
          Builder(
            builder: (context) {
              final platforms = group.$3
                  .map(_messagingPlatformById)
                  .nonNulls
                  .where((platform) {
                    final status =
                        controller.messagingStatuses[platform.id] ??
                        MessagingPlatformStatus.empty(platform.id);
                    final haystack =
                        '${platform.label} ${platform.subtitle} ${group.$1}'
                            .toLowerCase();
                    return _matchesMessagingStatusFilter(status) &&
                        (query.isEmpty || haystack.contains(query));
                  })
                  .toList(growable: false);
              if (platforms.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessagingGroupHeader(
                      title: group.$1,
                      subtitle: group.$2,
                      count: platforms.length,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 1380
                            ? 4
                            : width >= 1020
                            ? 3
                            : width >= 700
                            ? 2
                            : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: platforms.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 268,
                              ),
                          itemBuilder: (context, index) {
                            final platform = platforms[index];
                            return _MessagingCard(
                              platform: platform,
                              status:
                                  controller.messagingStatuses[platform.id] ??
                                  MessagingPlatformStatus.empty(platform.id),
                              accessCatalog: controller
                                  .currentMessagingAccessCatalog(platform.id),
                              controller: controller,
                              onConnect: () => openMessagingConfig(context, controller, platform),
                              onDisconnect: () => controller
                                  .disconnectMessagingPlatform(platform.id),
                              onLogout: () => controller
                                  .logoutMessagingPlatform(platform.id),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        if (!hasMatches) ...[
          const SizedBox(height: 10),
          const _EmptyCard(
            title: 'No platforms match',
            subtitle:
                'Adjust the search or status filter to see more messaging channels.',
          ),
          const SizedBox(height: 22),
        ],
        _MessagingActivityPanel(messages: controller.messagingMessages),
      ],
    );
  }

  bool _hasMessagingMatches(
    NeoAgentController controller,
    List<(String, String, List<String>)> groups,
    String query,
  ) {
    for (final group in groups) {
      for (final key in group.$3) {
        final platform = _messagingPlatformById(key);
        if (platform == null) continue;
        final status =
            controller.messagingStatuses[platform.id] ??
            MessagingPlatformStatus.empty(platform.id);
        final haystack = '${platform.label} ${platform.subtitle} ${group.$1}'
            .toLowerCase();
        if (_matchesMessagingStatusFilter(status) &&
            (query.isEmpty || haystack.contains(query))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesMessagingStatusFilter(MessagingPlatformStatus? status) {
    final effective = status ?? MessagingPlatformStatus.empty('unknown');
    return switch (_statusFilter) {
      'connected' => effective.isConnected,
      'configured' => effective.status != 'not_configured',
      'attention' => const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(effective.status),
      _ => true,
    };
  }
}

class _MessagingStatusCounts {
  const _MessagingStatusCounts({
    required this.total,
    required this.connected,
    required this.configured,
    required this.attention,
  });

  final int total;
  final int connected;
  final int configured;
  final int attention;

  factory _MessagingStatusCounts.from(
    Map<String, MessagingPlatformStatus> statuses,
  ) {
    var connected = 0;
    var configured = 0;
    var attention = 0;
    for (final platform in messagingPlatforms) {
      final status =
          statuses[platform.id] ?? MessagingPlatformStatus.empty(platform.id);
      if (status.isConnected) connected++;
      if (status.status != 'not_configured') configured++;
      if (const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(status.status)) {
        attention++;
      }
    }
    return _MessagingStatusCounts(
      total: messagingPlatforms.length,
      connected: connected,
      configured: configured,
      attention: attention,
    );
  }
}

class _MessagingOverviewStrip extends StatelessWidget {
  const _MessagingOverviewStrip({required this.counts});

  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MessagingMetricCard(
        icon: Icons.link_rounded,
        label: 'Connected',
        value: '${counts.connected}',
        helper: '${counts.configured} configured',
        color: _success,
      ),
      _MessagingMetricCard(
        icon: Icons.error_outline_rounded,
        label: 'Needs attention',
        value: '${counts.attention}',
        helper: 'Reconnect or finish setup',
        color: counts.attention > 0 ? _warning : _textSecondary,
      ),
      _MessagingMetricCard(
        icon: Icons.apps_rounded,
        label: 'Available',
        value: '${counts.total}',
        helper: 'Native and webhook channels',
        color: _info,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                cards[index],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }
}

class _MessagingMetricCard extends StatelessWidget {
  const _MessagingMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: TextStyle(color: _textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagingToolbar extends StatelessWidget {
  const _MessagingToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.counts,
  });

  final TextEditingController controller;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String)>[
      ('all', 'All ${counts.total}'),
      ('connected', 'Connected ${counts.connected}'),
      ('configured', 'Configured ${counts.configured}'),
      ('attention', 'Attention ${counts.attention}'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final search = TextField(
            controller: controller,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Find a platform',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clear,
                      icon: Icon(Icons.close_rounded),
                    ),
            ),
          );
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in filters)
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: selectedFilter == filter.$1,
                  onSelected: (_) => onFilterChanged(filter.$1),
                  selectedColor: _accent.withValues(alpha: 0.18),
                  backgroundColor: _bgCard,
                  side: BorderSide(
                    color: selectedFilter == filter.$1
                        ? _accent.withValues(alpha: 0.42)
                        : _borderLight,
                  ),
                  labelStyle: TextStyle(
                    color: selectedFilter == filter.$1
                        ? _textPrimary
                        : _textSecondary,
                    fontWeight: selectedFilter == filter.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), chips],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              Flexible(child: chips),
            ],
          );
        },
      ),
    );
  }
}

class _MessagingQrPanel extends StatelessWidget {
  const _MessagingQrPanel({required this.qrState});

  final MessagingQrState qrState;

  @override
  Widget build(BuildContext context) {
    final qrImage = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(
        data: qrState.qr,
        size: 168,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusPill(label: 'Awaiting scan', color: _warning),
        const SizedBox(height: 12),
        Text(
          'Scan to finish ${qrState.platformLabel}',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this panel open until the platform confirms the connection.',
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warning.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 16),
                Center(child: qrImage),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              qrImage,
            ],
          );
        },
      ),
    );
  }
}

class _MessagingGroupHeader extends StatelessWidget {
  const _MessagingGroupHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: _textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusPill(label: '$count shown', color: _textSecondary),
      ],
    );
  }
}

class _MessagingActivityPanel extends StatelessWidget {
  const _MessagingActivityPanel({required this.messages});

  final List<MessagingMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Channel Activity',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: '${messages.length} events', color: _info),
            ],
          ),
          const SizedBox(height: 14),
          if (messages.isEmpty)
            const _EmptyCard(
              title: 'No recent channel activity',
              subtitle:
                  'Incoming and outgoing channel messages will appear here.',
            )
          else
            Column(
              children: [
                for (final message in messages.take(12))
                  _MessagingActivityItem(message: message),
              ],
            ),
        ],
      ),
    );
  }
}

class _MessagingActivityItem extends StatelessWidget {
  const _MessagingActivityItem({required this.message});

  final MessagingMessage message;

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.outgoing;
    final color = isOutbound ? _accent : _success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOutbound ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: message.platform.toUpperCase(),
                      color: _info,
                    ),
                    Text(
                      message.senderLabel,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      message.createdAtLabel,
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.content.ifEmpty('[empty]'),
                  style: TextStyle(color: _textSecondary, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RunsPanel extends StatefulWidget {
  const RunsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsPanel> createState() => _RunsPanelState();
}

class _RunsPanelState extends State<RunsPanel> {
  late final TextEditingController _searchController;
  String? _selectedRunId;
  String _statusFilter = 'all';
  RunDetailSnapshot? _detail;
  bool _loadingDetail = false;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _syncSelection();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RunsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _syncSelection();
  }

  List<RunSummary> get _filteredRuns {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.recentRuns.where((run) {
      final statusMatches =
          _statusFilter == 'all' ||
          (_statusFilter == 'failed'
              ? run.isFailure
              : run.status.toLowerCase() == _statusFilter);
      if (!statusMatches) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        run.title,
        run.status,
        run.model,
        run.triggerSource,
        run.error,
        run.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _syncSelection() {
    final runs = _filteredRuns;
    if (runs.isEmpty) {
      _selectedRunId = null;
      _detail = null;
      _detailError = null;
      return;
    }
    if (_selectedRunId == null ||
        !runs.any((run) => run.id == _selectedRunId)) {
      _selectRun(runs.first.id);
    }
  }

  Future<void> _selectRun(String runId, {bool force = false}) async {
    setState(() {
      _selectedRunId = runId;
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final detail = await widget.controller.fetchRunDetail(
        runId,
        force: force,
      );
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _detail = detail;
        _loadingDetail = false;
        _detailError = null;
      });
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'runs.ui',
        'detail.fetch_failed',
        data: <String, Object?>{'runId': runId},
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _loadingDetail = false;
        _detailError = widget.controller.friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _refreshRuns() async {
    await widget.controller.refreshRunsOnly();
    if (!mounted) {
      return;
    }
    final selectedRunId = _selectedRunId;
    if (selectedRunId != null &&
        _filteredRuns.any((run) => run.id == selectedRunId)) {
      await _selectRun(selectedRunId, force: true);
    } else {
      _syncSelection();
    }
    setState(() {});
  }

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });
    _syncSelection();
  }

  Future<void> _copyResponse(String response) async {
    if (response.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: response));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied final response')));
  }

  Future<void> _deleteSelectedRun() async {
    final run = widget.controller.recentRuns.cast<RunSummary?>().firstWhere(
      (item) => item?.id == _selectedRunId,
      orElse: () => null,
    );
    if (run == null) {
      return;
    }
    await _confirmDelete(
      context,
      title: 'Delete run?',
      message:
          'Remove "${run.title}" and its recorded steps from the run history?',
      onConfirm: () async {
        await widget.controller.deleteRun(run.id);
        if (!mounted) {
          return;
        }
        _syncSelection();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filteredRuns = _filteredRuns;
    final selected = filteredRuns.cast<RunSummary?>().firstWhere(
      (run) => run?.id == _selectedRunId,
      orElse: () => null,
    );
    final detail = _detail?.run.id == selected?.id ? _detail : null;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Runs',
          subtitle:
              'Inspect recent runs, failures, tool steps, and final responses.',
          trailing: OutlinedButton.icon(
            onPressed: _refreshRuns,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.activeRun != null ||
            controller.toolEvents.isNotEmpty) ...<Widget>[
          _RunStatusPanel(
            run: controller.activeRun,
            tools: controller.toolEvents,
          ),
          const SizedBox(height: 16),
        ],
        if (controller.recentRuns.isEmpty)
          const _EmptyCard(
            title: 'No runs yet',
            subtitle:
                'Send a task from chat and its execution history will show up here.',
          )
        else ...<Widget>[
          _RunsMetricsStrip(
            runs: filteredRuns,
            totalLoaded: controller.recentRuns.length,
          ),
          const SizedBox(height: 16),
          _RunsFilterBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            onStatusChanged: _setStatusFilter,
          ),
          const SizedBox(height: 16),
          if (filteredRuns.isEmpty)
            const _EmptyCard(
              title: 'No matching runs',
              subtitle:
                  'Try clearing the search or switching the status filter.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1120;
                final historyPane = _RunsHistoryPane(
                  runs: filteredRuns,
                  selectedRunId: _selectedRunId,
                  onSelect: _selectRun,
                );
                final detailPane = _RunDetailWorkspace(
                  run: selected,
                  detail: detail,
                  errorMessage: _detailError,
                  loading: _loadingDetail,
                  onDelete: _deleteSelectedRun,
                  onCopyResponse: _copyResponse,
                );
                if (!wide) {
                  return Column(
                    children: <Widget>[
                      detailPane,
                      const SizedBox(height: 16),
                      historyPane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 360, child: historyPane),
                    const SizedBox(width: 16),
                    Expanded(child: detailPane),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }
}

class _MessagingCard extends StatelessWidget {
  const _MessagingCard({
    required this.platform,
    required this.status,
    required this.accessCatalog,
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
    required this.onLogout,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingPlatformStatus? status;
  final MessagingAccessCatalog accessCatalog;
  final NeoAgentController controller;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final connected = status?.isConnected ?? false;
    final configured = status != null && status!.status != 'not_configured';
    final accent = platform.accent;
    final actionLabel = connected
        ? 'Connected'
        : configured
        ? 'Reconnect'
        : 'Connect';
    final accessLabel = accessCatalog.summary.ifEmpty('Access policy');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: connected ? accent.withValues(alpha: 0.48) : _borderLight,
        ),
        boxShadow: [
          if (connected)
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(platform.icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.label,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status?.authLabel ?? 'Not configured',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: connected
                    ? 'Live'
                    : configured
                    ? 'Ready'
                    : 'Setup',
                color: connected
                    ? _success
                    : configured
                    ? _warning
                    : _textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            platform.subtitle,
            style: TextStyle(color: _textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MessagingMiniPill(
                icon: Icons.admin_panel_settings_outlined,
                label: accessLabel,
              ),
              if (configured && !connected)
                const _MessagingMiniPill(
                  icon: Icons.tune_rounded,
                  label: 'Configured',
                ),
              if (platform.configFields.isNotEmpty)
                _MessagingMiniPill(
                  icon: Icons.edit_note_rounded,
                  label: '${platform.configFields.length} fields',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: onDisconnect,
                        icon: Icon(Icons.link_off_rounded, size: 18),
                        label: Text(
                          'Disconnect',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onConnect,
                        icon: Icon(Icons.power_settings_new_rounded, size: 18),
                        label: Text(
                          actionLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Access policy',
                onPressed: () => _editAccessPolicy(context, controller),
                icon: Icon(Icons.group_add_outlined),
              ),
              if (platform.id == 'telnyx') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Voice PIN',
                  onPressed: () => _editTelnyxSecret(context, controller),
                  icon: Icon(Icons.password_outlined),
                ),
              ],
              if (connected) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  icon: Icon(Icons.logout_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAccessPolicy(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final catalog = await controller.loadMessagingAccessCatalog(
      platform.id,
      force: true,
    );
    if (!context.mounted) return;
    await _showMessagingAccessPolicyDialog(
      context,
      platform: platform,
      initialCatalog: catalog,
      onRefreshCatalog: () =>
          controller.loadMessagingAccessCatalog(platform.id, force: true),
      onSave: (policy) =>
          controller.saveMessagingAccessPolicy(platform.id, policy),
    );
  }

  Future<void> _editTelnyxSecret(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final initial =
        controller.settings['platform_voice_secret_telnyx']?.toString() ?? '';
    final saved = await _showTextSettingDialog(
      context,
      title: 'Voice PIN',
      subtitle:
          'Set the PIN callers must enter before the voice agent answers.',
      label: 'PIN or passphrase',
      initialValue: initial,
      obscureText: true,
    );
    if (saved != null) {
      await controller.saveTelnyxVoiceSecret(saved);
    }
  }
}

class _MessagingRuleSelection {
  const _MessagingRuleSelection({required this.bucket, required this.rule});

  final String bucket;
  final MessagingAccessRule rule;
}

Future<void> _showMessagingAccessPolicyDialog(
  BuildContext context, {
  required MessagingPlatformDescriptor platform,
  required MessagingAccessCatalog initialCatalog,
  required Future<MessagingAccessCatalog> Function() onRefreshCatalog,
  required Future<void> Function(MessagingAccessPolicy policy) onSave,
}) async {
  var catalog = initialCatalog;
  var policy = initialCatalog.policy;

  List<MessagingAccessRule> dedupeRules(List<MessagingAccessRule> rules) {
    final seen = <String>{};
    final result = <MessagingAccessRule>[];
    for (final rule in rules) {
      if (rule.value.trim().isEmpty) continue;
      if (!seen.add(rule.id)) continue;
      result.add(rule);
    }
    return result;
  }

  void addRule(
    _MessagingRuleSelection selection,
    void Function(void Function()) setLocalState,
  ) {
    setLocalState(() {
      switch (selection.bucket) {
        case 'directRules':
          policy = policy.copyWith(
            directPolicy: policy.directPolicy == 'disabled'
                ? 'allowlist'
                : policy.directPolicy,
            directRules: dedupeRules(<MessagingAccessRule>[
              ...policy.directRules,
              selection.rule,
            ]),
          );
          break;
        case 'sharedActorRules':
          policy = policy.copyWith(
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedActorRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedActorRules,
              selection.rule,
            ]),
          );
          break;
        default:
          policy = policy.copyWith(
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedSpaceRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedSpaceRules,
              selection.rule,
            ]),
          );
      }
    });
  }

  void removeRule(
    String bucket,
    MessagingAccessRule rule,
    void Function(void Function()) setLocalState,
  ) {
    setLocalState(() {
      switch (bucket) {
        case 'directRules':
          policy = policy.copyWith(
            directRules: policy.directRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
          break;
        case 'sharedActorRules':
          policy = policy.copyWith(
            sharedActorRules: policy.sharedActorRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
          break;
        default:
          policy = policy.copyWith(
            sharedSpaceRules: policy.sharedSpaceRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
      }
    });
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final capabilities = catalog.capabilities;
          final summaryText = [
            'DMs ${policy.directPolicy}',
            if (capabilities.supportsSharedPolicy)
              'shared ${policy.sharedPolicy}',
            if (capabilities.supportsMentionGate)
              policy.requireMentionInShared
                  ? 'mentions required'
                  : 'mentions optional',
            if (policy.totalRuleCount > 0) '${policy.totalRuleCount} rules',
          ].join(' • ');

          return AlertDialog(
            backgroundColor: _bgCard,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            title: Text('${platform.label} Access Policy'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MessagingAccessSummaryCard(
                      accent: platform.accent,
                      summary: summaryText,
                      hint: capabilities.manualEntryHint.ifEmpty(
                        'Choose who can reach this platform and how shared spaces behave.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (capabilities.supportsDirectPolicy)
                      _AccessModeField(
                        label: 'Direct messages',
                        value: policy.directPolicy,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(directPolicy: value);
                        }),
                      ),
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 12),
                      _AccessModeField(
                        label: 'Shared spaces',
                        value: policy.sharedPolicy,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(sharedPolicy: value);
                        }),
                      ),
                    ],
                    if (capabilities.supportsMentionGate) ...<Widget>[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Require mention in shared spaces'),
                        subtitle: Text(
                          'Keep channels quiet until the bot is directly mentioned.',
                          style: TextStyle(color: _textSecondary),
                        ),
                        value: policy.requireMentionInShared,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(
                            requireMentionInShared: value,
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () async {
                            final selection =
                                await _showMessagingAccessRulePicker(
                                  context,
                                  platform: platform,
                                  catalog: catalog,
                                );
                            if (selection != null) {
                              addRule(selection, setLocalState);
                            }
                          },
                          icon: Icon(Icons.add_rounded),
                          label: Text('Add Rule'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final refreshed = await onRefreshCatalog();
                            if (!context.mounted) return;
                            setLocalState(() {
                              catalog = refreshed;
                            });
                          },
                          icon: Icon(Icons.travel_explore_rounded),
                          label: Text('Refresh Discovery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AccessRuleSection(
                      title: 'Direct senders',
                      subtitle: 'Who can start a one-to-one conversation.',
                      rules: policy.directRules,
                      emptyLabel: 'No direct sender rules yet.',
                      onRemove: (rule) =>
                          removeRule('directRules', rule, setLocalState),
                    ),
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        title: 'Shared spaces',
                        subtitle:
                            'Which channels, groups, rooms, or servers can trigger the agent.',
                        rules: policy.sharedSpaceRules,
                        emptyLabel: 'No shared-space rules yet.',
                        onRemove: (rule) =>
                            removeRule('sharedSpaceRules', rule, setLocalState),
                      ),
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        title: 'Shared actors',
                        subtitle:
                            'Optional extra filter for who inside allowed shared spaces can trigger the agent.',
                        rules: policy.sharedActorRules,
                        emptyLabel: 'No shared-actor rules yet.',
                        onRemove: (rule) =>
                            removeRule('sharedActorRules', rule, setLocalState),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await onSave(policy);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text('Save Policy'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AccessModeField extends StatelessWidget {
  const _AccessModeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'allowlist', child: Text('Allowlist only')),
            DropdownMenuItem(value: 'open', child: Text('Open access')),
            DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _AccessRuleSection extends StatelessWidget {
  const _AccessRuleSection({
    required this.title,
    required this.subtitle,
    required this.rules,
    required this.emptyLabel,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final List<MessagingAccessRule> rules;
  final String emptyLabel;
  final ValueChanged<MessagingAccessRule> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            Text(emptyLabel, style: TextStyle(color: _textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules
                  .map((rule) {
                    return Chip(
                      label: Text('${rule.scopeLabel}: ${rule.displayLabel}'),
                      deleteIcon: Icon(Icons.close_rounded, size: 18),
                      onDeleted: () => onRemove(rule),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

Future<_MessagingRuleSelection?> _showMessagingAccessRulePicker(
  BuildContext context, {
  required MessagingPlatformDescriptor platform,
  required MessagingAccessCatalog catalog,
}) async {
  return showModalBottomSheet<_MessagingRuleSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _bgCard,
    builder: (sheetContext) =>
        _MessagingAccessRulePickerSheet(platform: platform, catalog: catalog),
  );
}

class _MessagingAccessRulePickerSheet extends StatefulWidget {
  const _MessagingAccessRulePickerSheet({
    required this.platform,
    required this.catalog,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingAccessCatalog catalog;

  @override
  State<_MessagingAccessRulePickerSheet> createState() =>
      _MessagingAccessRulePickerSheetState();
}

class _MessagingAccessRulePickerSheetState
    extends State<_MessagingAccessRulePickerSheet> {
  late final TextEditingController _queryController;
  late String _selectedBucket;
  late String _selectedScope;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _selectedBucket = widget.catalog.capabilities.directRuleScopes.isNotEmpty
        ? 'directRules'
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? 'sharedSpaceRules'
              : 'sharedActorRules');
    _selectedScope = widget.catalog.capabilities.directRuleScopes.isNotEmpty
        ? widget.catalog.capabilities.directRuleScopes.first
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? widget.catalog.capabilities.sharedSpaceRuleScopes.first
              : (widget.catalog.capabilities.sharedActorRuleScopes.isNotEmpty
                    ? widget.catalog.capabilities.sharedActorRuleScopes.first
                    : 'chat'));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MessagingAccessRulePickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectedScope();
  }

  List<String> _scopesForBucket() {
    switch (_selectedBucket) {
      case 'directRules':
        return widget.catalog.capabilities.directRuleScopes;
      case 'sharedActorRules':
        return widget.catalog.capabilities.sharedActorRuleScopes;
      default:
        return widget.catalog.capabilities.sharedSpaceRuleScopes;
    }
  }

  void _syncSelectedScope() {
    final availableScopes = _scopesForBucket();
    if (availableScopes.isEmpty || availableScopes.contains(_selectedScope)) {
      return;
    }
    _selectedScope = availableScopes.first;
  }

  @override
  Widget build(BuildContext context) {
    final availableScopes = _scopesForBucket();
    final query = _queryController.text.trim().toLowerCase();
    final targets =
        <MessagingAccessTarget>[
              ...widget.catalog.suggestedTargets,
              ...widget.catalog.discoveredTargets,
            ]
            .where((target) {
              if (target.bucket != _selectedBucket) return false;
              if (query.isEmpty) return true;
              final haystack =
                  '${target.label} ${target.subtitle} ${target.scope} ${target.value}'
                      .toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Add Access Rule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a preset, a discovered target, or enter an id manually for ${widget.platform.label}.',
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (widget.catalog.capabilities.directRuleScopes.isNotEmpty)
                  ChoiceChip(
                    label: Text('Direct'),
                    selected: _selectedBucket == 'directRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'directRules';
                      _syncSelectedScope();
                    }),
                  ),
                if (widget
                    .catalog
                    .capabilities
                    .sharedSpaceRuleScopes
                    .isNotEmpty)
                  ChoiceChip(
                    label: Text('Shared spaces'),
                    selected: _selectedBucket == 'sharedSpaceRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedSpaceRules';
                      _syncSelectedScope();
                    }),
                  ),
                if (widget
                    .catalog
                    .capabilities
                    .sharedActorRuleScopes
                    .isNotEmpty)
                  ChoiceChip(
                    label: Text('Shared actors'),
                    selected: _selectedBucket == 'sharedActorRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedActorRules';
                      _syncSelectedScope();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search discovered targets',
              ),
            ),
            const SizedBox(height: 16),
            if (targets.isNotEmpty) ...<Widget>[
              Text(
                'Suggested & discovered',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...targets.take(10).map((target) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(target.label),
                  subtitle: Text(
                    target.subtitle.ifEmpty(
                      '${target.scope} • ${target.value}',
                    ),
                  ),
                  trailing: Icon(Icons.add_circle_outline_rounded),
                  onTap: () => Navigator.of(context).pop(
                    _MessagingRuleSelection(
                      bucket: target.bucket,
                      rule: target.asRule,
                    ),
                  ),
                );
              }),
              const Divider(height: 24),
            ],
            Text('Manual entry', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (availableScopes.isNotEmpty)
              InputDecorator(
                decoration: InputDecoration(labelText: 'Rule scope'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedScope,
                    isExpanded: true,
                    items: availableScopes
                        .map(
                          (scope) => DropdownMenuItem<String>(
                            value: scope,
                            child: Text(scope.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedScope = value);
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'ID / value',
                helperText: widget.catalog.capabilities.manualEntryHint,
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) return;
                Navigator.of(context).pop(
                  _MessagingRuleSelection(
                    bucket: _selectedBucket,
                    rule: MessagingAccessRule(
                      scope: _selectedScope,
                      value: trimmed,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showTextSettingDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String label,
  required String initialValue,
  bool obscureText = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(subtitle, style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscureText,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _MessagingMiniPill extends StatelessWidget {
  const _MessagingMiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsMetricsStrip extends StatelessWidget {
  const _RunsMetricsStrip({required this.runs, required this.totalLoaded});

  final List<RunSummary> runs;
  final int totalLoaded;

  @override
  Widget build(BuildContext context) {
    final running = runs.where((run) => run.status == 'running').length;
    final failed = runs.where((run) => run.isFailure).length;
    final completed = runs.where((run) => run.status == 'completed').length;
    final tokens = runs.fold<int>(0, (sum, run) => sum + run.totalTokens);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _RunMetricCard(
          title: 'Showing',
          value: '${runs.length}',
          helper: totalLoaded == runs.length
              ? 'Recent runs loaded'
              : 'Filtered from $totalLoaded loaded runs',
          color: _info,
        ),
        _RunMetricCard(
          title: 'Completed',
          value: '$completed',
          helper: 'Finished successfully',
          color: _success,
        ),
        _RunMetricCard(
          title: 'Failed',
          value: '$failed',
          helper: 'Need attention',
          color: _danger,
        ),
        _RunMetricCard(
          title: 'Tokens',
          value: _formatNumber(tokens),
          helper: 'Across visible runs',
          color: _accentHover,
        ),
        if (running > 0)
          _RunMetricCard(
            title: 'Running',
            value: '$running',
            helper: 'Still in progress',
            color: _warning,
          ),
      ],
    );
  }
}

class _RunMetricCard extends StatelessWidget {
  const _RunMetricCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String title;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(helper, style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}

class _RunsFilterBar extends StatelessWidget {
  const _RunsFilterBar({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <String>['all', 'running', 'completed', 'failed'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Filter Runs'),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, model, trigger, error, or run id',
                suffixIcon: searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters.map((filter) {
                return FilterChip(
                  label: Text(_titleCase(filter)),
                  selected: statusFilter == filter,
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) => onStatusChanged(filter),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsHistoryPane extends StatelessWidget {
  const _RunsHistoryPane({
    required this.runs,
    required this.selectedRunId,
    required this.onSelect,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Run History')),
                Text(
                  '${runs.length} items',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...runs.map((run) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunHistoryRow(
                  run: run,
                  selected: run.id == selectedRunId,
                  onTap: () => onSelect(run.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RunHistoryRow extends StatelessWidget {
  const _RunHistoryRow({
    required this.run,
    required this.selected,
    required this.onTap,
  });

  final RunSummary run;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _accentMuted : _bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _accent : _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: run.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    run.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${run.triggerLabel} • ${run.createdAtLabel}${run.durationLabel == 'In progress' ? '' : ' • ${run.durationLabel}'}',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${run.modelLabel} • ${run.totalTokensLabel} tokens',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  if (run.error.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      run.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _danger,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _StatusPill(label: run.statusLabel, color: run.statusColor),
                const SizedBox(height: 12),
                Icon(
                  Icons.chevron_right,
                  color: selected ? _textPrimary : _textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailWorkspace extends StatelessWidget {
  const _RunDetailWorkspace({
    required this.run,
    required this.detail,
    required this.errorMessage,
    required this.loading,
    required this.onDelete,
    required this.onCopyResponse,
  });

  final RunSummary? run;
  final RunDetailSnapshot? detail;
  final String? errorMessage;
  final bool loading;
  final Future<void> Function() onDelete;
  final Future<void> Function(String response) onCopyResponse;

  @override
  Widget build(BuildContext context) {
    if (run == null) {
      return const _EmptyCard(
        title: 'Select a run',
        subtitle: 'Pick a run from the history list to inspect its steps.',
      );
    }

    final selectedRun = run!;
    final snapshot = detail;
    return Column(
      children: <Widget>[
        _RunHeroCard(run: selectedRun, onDelete: onDelete),
        const SizedBox(height: 16),
        if (loading && snapshot == null)
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading run detail...',
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (errorMessage case final message?) ...<Widget>[
          _InlineError(message: message),
          const SizedBox(height: 16),
        ] else if (snapshot != null) ...<Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _RunMetricCard(
                title: 'Steps',
                value: '${snapshot.steps.length}',
                helper: 'Recorded events',
                color: _info,
              ),
              _RunMetricCard(
                title: 'Completed tools',
                value: '${snapshot.completedTools}',
                helper: 'Successful tool calls',
                color: _success,
              ),
              _RunMetricCard(
                title: 'Failures',
                value: '${snapshot.failedTools}',
                helper: 'Tool errors',
                color: _danger,
              ),
              _RunMetricCard(
                title: 'Helpers',
                value: '${snapshot.helperCount}',
                helper: 'Subagents or helpers',
                color: _accentHover,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RunResponseCard(
            response: snapshot.response,
            onCopy: () => onCopyResponse(snapshot.response),
          ),
          const SizedBox(height: 16),
          _RunTimelineCard(steps: snapshot.steps, loading: loading),
        ] else
          const _EmptyCard(
            title: 'No detail available',
            subtitle: 'This run does not have step detail yet.',
          ),
      ],
    );
  }
}

class _RunHeroCard extends StatelessWidget {
  const _RunHeroCard({required this.run, required this.onDelete});

  final RunSummary run;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            run.statusColor.withValues(alpha: 0.18),
            _bgSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _StatusPill(
                          label: run.statusLabel,
                          color: run.statusColor,
                        ),
                        _MetaPill(
                          label: run.triggerLabel,
                          icon: Icons.bolt_outlined,
                        ),
                        _MetaPill(
                          label: run.modelLabel,
                          icon: Icons.memory_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      run.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MetaPill(
                          label: 'Started ${run.createdAtLabel}',
                          icon: Icons.schedule_outlined,
                        ),
                        _MetaPill(
                          label: run.durationLabel,
                          icon: Icons.timer_outlined,
                        ),
                        _MetaPill(
                          label: '${run.totalTokensLabel} tokens',
                          icon: Icons.toll_outlined,
                        ),
                        _MetaPill(
                          label: run.id.length <= 12
                              ? run.id
                              : '${run.id.substring(0, 12)}…',
                          icon: Icons.tag_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline),
                label: Text('Delete'),
              ),
            ],
          ),
          if (run.error.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x19EF4444),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4CEF4444)),
              ),
              child: Text(run.error, style: TextStyle(height: 1.45)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunResponseCard extends StatelessWidget {
  const _RunResponseCard({required this.response, required this.onCopy});

  final String response;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Final Response')),
                OutlinedButton.icon(
                  onPressed: response.trim().isEmpty ? null : onCopy,
                  icon: Icon(Icons.copy_all_outlined),
                  label: Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response.trim().isEmpty)
              Text(
                'No final response was captured for this run.',
                style: TextStyle(color: _textSecondary),
              )
            else
              MarkdownBody(
                data: response,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _textPrimary,
                        height: 1.6,
                      ),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        backgroundColor: _bgSecondary,
                        color: _textPrimary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _bgSecondary,
                        border: Border.all(color: _border),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunTimelineCard extends StatelessWidget {
  const _RunTimelineCard({required this.steps, required this.loading});

  final List<RunStepItem> steps;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Step Timeline')),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              Text(
                'No run steps recorded yet.',
                style: TextStyle(color: _textSecondary),
              )
            else
              ...steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RunStepCard(step: step),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RunStepCard extends StatelessWidget {
  const _RunStepCard({required this.step});

  final RunStepItem step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded:
              step.status == 'failed' || step.status == 'running',
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: step.statusColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step.displayIndex}',
                style: TextStyle(
                  color: step.statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(step.label, style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                step.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusPill(label: step.statusLabel, color: step.statusColor),
                  _MetaPill(label: step.typeLabel, icon: Icons.layers_outlined),
                  if (step.startedAt != null)
                    _MetaPill(
                      label: step.startedAtLabel!,
                      icon: Icons.schedule_outlined,
                    ),
                  if (step.durationLabel != null)
                    _MetaPill(
                      label: step.durationLabel!,
                      icon: Icons.timer_outlined,
                    ),
                  if (step.tokensUsed > 0)
                    _MetaPill(
                      label: '${_formatNumber(step.tokensUsed)} tokens',
                      icon: Icons.toll_outlined,
                    ),
                ],
              ),
            ],
          ),
          children: <Widget>[
            if (step.description.trim().isNotEmpty &&
                step.description.trim() != step.summary.trim())
              _RunDetailBlock(label: 'Description', value: step.description),
            if (step.inputSummary.trim().isNotEmpty)
              _RunDetailBlock(label: 'Input summary', value: step.inputSummary),
            if (step.toolInput.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Tool input',
                value: _truncateRunText(step.toolInput),
                monospace: true,
              ),
            if (step.error.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Error',
                value: step.error,
                monospace: true,
              )
            else if (step.result.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Result',
                value: _truncateRunText(step.result),
                monospace: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailBlock extends StatelessWidget {
  const _RunDetailBlock({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              value,
              style: TextStyle(
                height: 1.5,
                fontSize: 12.5,
                color: _textPrimary,
                fontFamily: monospace
                    ? GoogleFonts.jetBrainsMono().fontFamily
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openMessagingConfig(BuildContext context, NeoAgentController controller, 
    MessagingPlatformDescriptor platform,
  ) async {
    switch (platform.id) {
      case 'whatsapp':
        await _connectMessagingPlatformHelper(context, controller, 
          platform: 'whatsapp',
          platformLabel: platform.label,
        );
        return;
      case 'telnyx':
        return _openTelnyxConfigHelper(context, controller);
      default:
        return _openGenericMessagingConfigHelper(context, controller, platform);
    }
  }

  Future<bool> _connectMessagingPlatformHelper(BuildContext context, NeoAgentController controller, {
    required String platform,
    required String platformLabel,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    try {
      await controller.connectMessagingPlatform(
        platform: platform,
        config: config,
        configSnapshot: configSnapshot,
      );
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to connect $platformLabel: ${controller.friendlyErrorMessage(error)}',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _openTelnyxConfigHelper(BuildContext context, NeoAgentController controller) async {
    final saved = _jsonMap(
      _decodeMaybeJson(controller.settings['telnyx_config']),
    );
    final apiKey = TextEditingController(
      text: saved['apiKey']?.toString() ?? '',
    );
    final phoneNumber = TextEditingController(
      text: saved['phoneNumber']?.toString() ?? '',
    );
    final connectionId = TextEditingController(
      text: saved['connectionId']?.toString() ?? '',
    );
    final webhookUrl = TextEditingController(
      text: saved['webhookUrl']?.toString() ?? controller.backendUrl,
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                backgroundColor: _bgCard,
                title: Text('Telnyx Voice'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: apiKey,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'API Key',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneNumber,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: connectionId,
                          decoration: const InputDecoration(
                            labelText: 'Connection ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: webhookUrl,
                          decoration: const InputDecoration(
                            labelText: 'Webhook Base URL',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Voice STT/TTS providers and models are configured in global Settings > Voice.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final config = <String, dynamic>{
                        'apiKey': apiKey.text.trim(),
                        'phoneNumber': phoneNumber.text.trim(),
                        'connectionId': connectionId.text.trim(),
                        'webhookUrl': webhookUrl.text.trim(),
                      };
                      final connected = await _connectMessagingPlatformHelper(context, controller, 
                        platform: 'telnyx',
                        platformLabel: 'Telnyx Voice',
                        config: config,
                        configSnapshot: <String, dynamic>{
                          'telnyx_config': jsonEncode(config),
                        },
                      );
                      if (connected && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Connect'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      apiKey.dispose();
      phoneNumber.dispose();
      connectionId.dispose();
      webhookUrl.dispose();
    }
  }

  Future<void> _openGenericMessagingConfigHelper(BuildContext context, NeoAgentController controller, 
    MessagingPlatformDescriptor platform,
  ) async {
    final saved = _jsonMap(
      _decodeMaybeJson(controller.settings[platform.settingsKey]),
    );
    final textControllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final field in platform.configFields) {
      final savedValue = field.settingsKey == null
          ? saved[field.key]
          : controller.settings[field.storageKey];
      if (field.kind == MessagingConfigFieldKind.boolean) {
        boolValues[field.key] =
            savedValue == true || savedValue?.toString() == 'true';
      } else {
        textControllers[field.key] = TextEditingController(
          text: savedValue?.toString() ?? field.defaultValue ?? '',
        );
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                backgroundColor: _bgCard,
                title: Text(platform.label),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (platform.configFields.isEmpty)
                          Text(
                            'No extra settings are required.',
                            style: TextStyle(color: _textSecondary),
                          )
                        else
                          ...platform.configFields.map((field) {
                            if (field.kind ==
                                MessagingConfigFieldKind.boolean) {
                              return SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(field.label),
                                value: boolValues[field.key] ?? false,
                                onChanged: (value) {
                                  setLocalState(() {
                                    boolValues[field.key] = value;
                                  });
                                },
                              );
                            }
                            final controller = textControllers[field.key]!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                controller: controller,
                                obscureText:
                                    field.obscure ||
                                    field.kind ==
                                        MessagingConfigFieldKind.password,
                                minLines:
                                    field.kind ==
                                        MessagingConfigFieldKind.multiline
                                    ? 4
                                    : 1,
                                maxLines:
                                    field.kind ==
                                        MessagingConfigFieldKind.multiline
                                    ? 8
                                    : 1,
                                decoration: InputDecoration(
                                  labelText: field.label,
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        if (platform.id == 'meshtastic')
                          Text(
                            'Meshtastic connects directly to the device TCP API on port 4403 by default. Normal chat is limited to the configured channel.',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          )
                        else
                          SelectableText(
                            'Inbound webhook: ${controller.backendUrl}/api/messaging/webhook/${platform.id}',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final config = <String, dynamic>{};
                      final snapshot = <String, dynamic>{};
                      for (final field in platform.configFields) {
                        if (field.kind == MessagingConfigFieldKind.boolean ||
                            !field.includeInConfig) {
                          continue;
                        }
                        final controller = textControllers[field.key];
                        final value = controller?.text.trim() ?? '';
                        if (value.isNotEmpty) config[field.key] = value;
                      }
                      for (final field in platform.configFields) {
                        if (field.kind == MessagingConfigFieldKind.boolean) {
                          final value = boolValues[field.key] ?? false;
                          if (field.includeInConfig) {
                            config[field.key] = value;
                          }
                          if (field.settingsKey != null) {
                            snapshot[field.storageKey] = value;
                          }
                        } else if (field.settingsKey != null) {
                          final controller = textControllers[field.key];
                          final value = controller?.text.trim() ?? '';
                          if (value.isNotEmpty) {
                            snapshot[field.storageKey] = value;
                          }
                        }
                      }
                      snapshot[platform.settingsKey] = jsonEncode(config);
                      final connected = await _connectMessagingPlatformHelper(context, controller, 
                        platform: platform.id,
                        platformLabel: platform.label,
                        config: config,
                        configSnapshot: snapshot,
                      );
                      if (connected && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Connect',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final controller in textControllers.values) {
        controller.dispose();
      }
    }
  }

