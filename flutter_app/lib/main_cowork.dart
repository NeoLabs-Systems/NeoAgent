part of 'main.dart';

class DesktopStandardWorkspace extends StatelessWidget {
  const DesktopStandardWorkspace({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        HomeView(controller: controller),
        Positioned(
          top: 12,
          right: 18,
          child: _DesktopModeSwitch(controller: controller),
        ),
      ],
    );
  }
}

class _DesktopModeSwitch extends StatelessWidget {
  const _DesktopModeSwitch({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Icons.dashboard_outlined, size: 18),
            label: Text('Standard'),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: Icon(Icons.terminal_rounded, size: 18),
            label: Text('Cowork'),
          ),
        ],
        selected: <bool>{controller.desktopCoworkMode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            controller.setDesktopCoworkMode(selection.first),
      ),
    );
  }
}

class CoworkHomeView extends StatefulWidget {
  const CoworkHomeView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<CoworkHomeView> createState() => _CoworkHomeViewState();
}

class _CoworkHomeViewState extends State<CoworkHomeView> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<SharedChatAttachment> _attachments = const <SharedChatAttachment>[];
  LiveVoiceCapture? _dictationCapture;
  final List<Uint8List> _dictationChunks = <Uint8List>[];
  bool _isDictating = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.refreshCowork());
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    unawaited(_dictationCapture?.dispose());
    super.dispose();
  }

  Future<void> _send() async {
    final content = _composer.text;
    if (content.trim().isEmpty && _attachments.isEmpty) return;
    final outgoingAttachments = _attachments;
    _composer.clear();
    setState(() => _attachments = const <SharedChatAttachment>[]);
    await widget.controller.sendCoworkMessage(
      content,
      sharedAttachments: outgoingAttachments,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _attachFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );
    if (!mounted || result == null) return;
    final selected = result.files
        .where((file) => file.path?.trim().isNotEmpty == true)
        .map(
          (file) => SharedChatAttachment(
            uri: file.path!,
            name: file.name,
            mimeType: _coworkMimeTypeForFileName(file.name),
            sizeBytes: file.size,
            source: 'file_picker',
          ),
        )
        .where((item) => item.isValid)
        .toList(growable: false);
    if (selected.isNotEmpty) {
      setState(
        () =>
            _attachments = <SharedChatAttachment>[..._attachments, ...selected],
      );
    }
  }

  Future<void> _toggleDictation() async {
    if (_isTranscribing) return;
    if (!_isDictating) {
      final capture = LiveVoiceCapture();
      _dictationCapture = capture;
      _dictationChunks.clear();
      try {
        await capture.start(
          onChunk: _dictationChunks.add,
          sampleRate: 16000,
          channels: 1,
        );
        if (mounted) setState(() => _isDictating = true);
      } catch (error) {
        await capture.dispose();
        _dictationCapture = null;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Microphone error: $error')));
        }
      }
      return;
    }

    final capture = _dictationCapture;
    _dictationCapture = null;
    setState(() {
      _isDictating = false;
      _isTranscribing = true;
    });
    try {
      await capture?.stop();
      if (_dictationChunks.isNotEmpty) {
        final bytes = _dictationChunks.fold<List<int>>(
          <int>[],
          (all, chunk) => all..addAll(chunk),
        );
        final transcript = await widget.controller.transcribeDictationAudio(
          audioBase64: base64Encode(Uint8List.fromList(bytes)),
        );
        if (mounted && transcript.trim().isNotEmpty) {
          final separator =
              _composer.text.isNotEmpty && !_composer.text.endsWith(' ')
              ? ' '
              : '';
          _composer.text = '${_composer.text}$separator$transcript';
          _composer.selection = TextSelection.collapsed(
            offset: _composer.text.length,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transcription failed: $error')));
      }
    } finally {
      await capture?.dispose();
      _dictationChunks.clear();
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _CoworkTopBar(controller: controller),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showWorkSurface = constraints.maxWidth >= 1180;
                  final chatsWidth = constraints.maxWidth >= 1450
                      ? 280.0
                      : 240.0;
                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: chatsWidth,
                        child: _CoworkChatRail(controller: controller),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _CoworkConversation(
                          controller: controller,
                          composer: _composer,
                          scrollController: _scroll,
                          onSend: _send,
                          attachments: _attachments,
                          onRemoveAttachment: (attachment) => setState(() {
                            _attachments = _attachments
                                .where((item) => item != attachment)
                                .toList(growable: false);
                          }),
                          onAttach: _attachFiles,
                          onDictate: _toggleDictation,
                          isDictating: _isDictating,
                          isTranscribing: _isTranscribing,
                        ),
                      ),
                      if (showWorkSurface) ...<Widget>[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: (constraints.maxWidth * 0.4)
                              .clamp(480.0, 680.0)
                              .toDouble(),
                          child: _CoworkWorkSurface(controller: controller),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoworkTopBar extends StatelessWidget {
  const _CoworkTopBar({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: colors.surfaceContainerLow,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[colors.primary, colors.tertiary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.code_rounded, color: colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Text(
            'NeoAgent Cowork',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          Icon(
            controller.socketConnected ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: controller.socketConnected ? colors.primary : colors.error,
          ),
          const SizedBox(width: 14),
          _DesktopModeSwitch(controller: controller),
        ],
      ),
    );
  }
}

class _CoworkChatRail extends StatelessWidget {
  const _CoworkChatRail({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.createCoworkChat,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New chat'),
              ),
            ),
          ),
          if (controller.isLoadingCowork && controller.coworkChats.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.coworkChats.isEmpty)
            const Expanded(
              child: _CoworkEmpty(
                icon: Icons.forum_outlined,
                title: 'No Cowork chats',
                message: 'Create a chat to plan or build with NeoAgent.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: controller.coworkChats.length,
                itemBuilder: (context, index) {
                  final chat = controller.coworkChats[index];
                  final selected = chat.id == controller.selectedCoworkChatId;
                  final thread = controller.coworkThreadFor(chat.id);
                  final status = thread.runStatus ?? chat.latestRun?.status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Material(
                      color: selected
                          ? colors.primaryContainer.withValues(alpha: 0.7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => controller.selectCoworkChat(chat.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            children: <Widget>[
                              _CoworkStatusDot(status: status),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      chat.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${chat.agentName} · ${chat.mode == CoworkInteractionMode.plan ? 'Plan' : 'Agent'} · ${chat.device.effective}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Chat actions',
                                iconSize: 18,
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    await _renameCoworkChat(
                                      context,
                                      controller,
                                      chat,
                                    );
                                  } else if (value == 'delete') {
                                    await _deleteCoworkChat(
                                      context,
                                      controller,
                                      chat,
                                    );
                                  }
                                },
                                itemBuilder: (_) =>
                                    const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _deleteCoworkChat(
  BuildContext context,
  NeoAgentController controller,
  CoworkChat chat,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Cowork chat?'),
      content: Text(
        '“${chat.title}” and its run history will be permanently deleted. Any active run will be stopped.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.deleteCoworkChat(chat.id);
}

Future<void> _renameCoworkChat(
  BuildContext context,
  NeoAgentController controller,
  CoworkChat chat,
) async {
  final text = TextEditingController(text: chat.title);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 160,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  text.dispose();
  if (name?.trim().isNotEmpty == true) {
    await controller.updateCoworkChat(chat.id, <String, dynamic>{
      'title': name!.trim(),
    });
  }
}

class _CoworkConversation extends StatelessWidget {
  const _CoworkConversation({
    required this.controller,
    required this.composer,
    required this.scrollController,
    required this.onSend,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onDictate,
    required this.isDictating,
    required this.isTranscribing,
  });

  final NeoAgentController controller;
  final TextEditingController composer;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final List<SharedChatAttachment> attachments;
  final ValueChanged<SharedChatAttachment> onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onDictate;
  final bool isDictating;
  final bool isTranscribing;

  @override
  Widget build(BuildContext context) {
    final chat = controller.selectedCoworkChat;
    final thread = controller.selectedCoworkThread;
    if (chat == null) {
      return const _CoworkEmpty(
        icon: Icons.add_comment_outlined,
        title: 'Choose a chat',
        message: 'Create or select a Cowork chat to begin.',
      );
    }
    final pending = thread.inputRequests
        .where((item) => item.isPending)
        .toList();
    return Column(
      children: <Widget>[
        _CoworkChatHeader(controller: controller, chat: chat, thread: thread),
        const Divider(height: 1),
        if (thread.hasLiveRun || thread.phase.isNotEmpty)
          _CoworkActivitySummary(thread: thread),
        Expanded(
          child: thread.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                  children: <Widget>[
                    for (final message in thread.messages)
                      _CoworkMessageBubble(message: message),
                    if (thread.streamingContent.trim().isNotEmpty)
                      _CoworkMessageBubble(
                        message: ChatEntry(
                          id: 'streaming',
                          role: 'assistant',
                          content: thread.streamingContent,
                          platform: 'cowork',
                          createdAt: DateTime.now(),
                          transient: true,
                          typing: true,
                        ),
                      ),
                    for (final request in pending)
                      _CoworkInputCard(
                        request: request,
                        onSubmit: (answers) =>
                            controller.answerCoworkInput(request, answers),
                      ),
                    if (chat.mode == CoworkInteractionMode.plan &&
                        !thread.hasLiveRun &&
                        pending.isEmpty &&
                        thread.messages.any(
                          (message) => message.role == 'assistant',
                        ))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: controller.implementSelectedCoworkPlan,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Implement plan'),
                        ),
                      ),
                  ],
                ),
        ),
        _CoworkComposer(
          controller: composer,
          enabled: controller.socketConnected && !thread.loading,
          steering: thread.hasLiveRun,
          onSend: onSend,
          attachments: attachments,
          onRemoveAttachment: onRemoveAttachment,
          onAttach: onAttach,
          onDictate: onDictate,
          isDictating: isDictating,
          isTranscribing: isTranscribing,
        ),
      ],
    );
  }
}

class _CoworkChatHeader extends StatelessWidget {
  const _CoworkChatHeader({
    required this.controller,
    required this.chat,
    required this.thread,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final CoworkThreadState thread;

  @override
  Widget build(BuildContext context) {
    final agents = controller.agentProfiles
        .where((agent) => agent.status != 'archived')
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              chat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: agents.any((agent) => agent.id == chat.agentId)
                  ? chat.agentId
                  : null,
              hint: const Text('Agent'),
              items: agents
                  .map(
                    (agent) => DropdownMenuItem<String>(
                      value: agent.id,
                      child: Text(agent.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  controller.updateCoworkChat(chat.id, <String, dynamic>{
                    'agentId': value,
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<CoworkInteractionMode>(
            segments: const <ButtonSegment<CoworkInteractionMode>>[
              ButtonSegment<CoworkInteractionMode>(
                value: CoworkInteractionMode.agent,
                icon: Icon(Icons.play_arrow_rounded, size: 16),
                label: Text('Agent'),
              ),
              ButtonSegment<CoworkInteractionMode>(
                value: CoworkInteractionMode.plan,
                icon: Icon(Icons.route_outlined, size: 16),
                label: Text('Plan'),
              ),
            ],
            selected: <CoworkInteractionMode>{chat.mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                controller.updateCoworkChat(chat.id, <String, dynamic>{
                  'mode': selection.first == CoworkInteractionMode.plan
                      ? 'plan'
                      : 'agent',
                }),
          ),
          const SizedBox(width: 10),
          _CoworkDeviceMenu(controller: controller, chat: chat),
          if (thread.hasLiveRun) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              tooltip: thread.runStatus == 'paused' ? 'Resume' : 'Pause',
              onPressed: thread.runStatus == 'paused'
                  ? controller.resumeCoworkRun
                  : controller.pauseCoworkRun,
              icon: Icon(
                thread.runStatus == 'paused'
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Stop',
              onPressed: controller.stopCoworkRun,
              icon: const Icon(Icons.stop_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoworkDeviceMenu extends StatelessWidget {
  const _CoworkDeviceMenu({required this.controller, required this.chat});

  final NeoAgentController controller;
  final CoworkChat chat;

  @override
  Widget build(BuildContext context) {
    final device = chat.device;
    return PopupMenuButton<String>(
      tooltip: 'Device target',
      onSelected: (value) =>
          controller.updateCoworkChat(chat.id, <String, dynamic>{
            'deviceTargetOverride': value == 'default' ? null : value,
          }),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'default',
          child: Text('Use Settings default (${device.setting})'),
        ),
        PopupMenuItem<String>(
          value: 'local',
          enabled: device.localAvailable,
          child: Text(
            device.localAvailable
                ? 'Local device'
                : 'Local device — unavailable',
          ),
        ),
        PopupMenuItem<String>(
          value: 'cloud',
          enabled: device.cloudAvailable,
          child: const Text('Cloud computer'),
        ),
      ],
      child: Chip(
        avatar: Icon(
          device.effective == 'local'
              ? Icons.laptop_mac_rounded
              : Icons.cloud_outlined,
          size: 16,
        ),
        label: Text(
          '${device.effective == 'local' ? 'Local' : 'Cloud'}${device.inherited ? ' · default' : ''}',
        ),
      ),
    );
  }
}

class _CoworkActivitySummary extends StatelessWidget {
  const _CoworkActivitySummary({required this.thread});

  final CoworkThreadState thread;

  @override
  Widget build(BuildContext context) {
    final latest = thread.activity.isEmpty ? null : thread.activity.last;
    return ExpansionTile(
      dense: true,
      leading: thread.hasLiveRun
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline, size: 18),
      title: Text(thread.phase.ifEmpty('Activity')),
      subtitle: latest == null
          ? null
          : Text(
              '${latest.label} · ${latest.status}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: thread.activity.length,
            itemBuilder: (context, index) {
              final item = thread.activity[thread.activity.length - 1 - index];
              return ListTile(
                dense: true,
                leading: Icon(
                  item.status == 'failed'
                      ? Icons.error_outline
                      : item.status == 'running'
                      ? Icons.pending_outlined
                      : Icons.check_rounded,
                  size: 18,
                ),
                title: Text(item.label),
                subtitle: Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: item.durationMs == null
                    ? null
                    : Text('${item.durationMs} ms'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CoworkMessageBubble extends StatelessWidget {
  const _CoworkMessageBubble({required this.message});

  final ChatEntry message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final interim = message.metadata['interim'] == true;
    final attachments = _jsonMapList(message.metadata['sharedAttachments']);
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: user
              ? colors.primaryContainer
              : interim
              ? colors.tertiaryContainer.withValues(alpha: 0.55)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!user && (message.senderName?.isNotEmpty == true || interim))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  interim ? 'STATUS UPDATE' : message.senderName!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (user)
              SelectableText(message.content)
            else
              MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.55),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: GoogleFonts.geistMono().fontFamily,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                    ),
              ),
            if (attachments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attachments
                    .map(
                      (attachment) => Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.attach_file_rounded, size: 15),
                        label: Text(
                          attachment['name']?.toString() ?? 'Attachment',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (message.typing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Working…',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoworkInputCard extends StatefulWidget {
  const _CoworkInputCard({required this.request, required this.onSubmit});

  final CoworkInputRequest request;
  final Future<void> Function(Map<String, String>) onSubmit;

  @override
  State<_CoworkInputCard> createState() => _CoworkInputCardState();
}

class _CoworkInputCardState extends State<_CoworkInputCard> {
  final Map<String, String> _answers = <String, String>{};
  final Map<String, TextEditingController> _custom =
      <String, TextEditingController>{};
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _custom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'NeoAgent needs your input',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            for (final question in widget.request.questions) ...<Widget>[
              Text(
                question.header,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(question.question),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _answers[question.id],
                onChanged: (value) => setState(() {
                  if (value != null) {
                    _answers[question.id] = value;
                    _custom[question.id]?.clear();
                  }
                }),
                child: Column(
                  children: <Widget>[
                    for (final option in question.options)
                      RadioListTile<String>(
                        dense: true,
                        value: option.label,
                        title: Text(
                          option.recommended
                              ? '${option.label} (Recommended)'
                              : option.label,
                        ),
                        subtitle: Text(option.description),
                      ),
                  ],
                ),
              ),
              if (question.allowCustom)
                TextField(
                  controller: _custom.putIfAbsent(
                    question.id,
                    TextEditingController.new,
                  ),
                  decoration: const InputDecoration(labelText: 'Custom answer'),
                  onChanged: (value) => setState(() {
                    if (value.trim().isNotEmpty) {
                      _answers[question.id] = value.trim();
                    } else {
                      _answers.remove(question.id);
                    }
                  }),
                ),
              const SizedBox(height: 14),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed:
                    _submitting ||
                        widget.request.questions.any(
                          (question) =>
                              _answers[question.id]?.trim().isEmpty != false,
                        )
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onSubmit(_answers);
                        if (mounted) setState(() => _submitting = false);
                      },
                child: Text(_submitting ? 'Submitting…' : 'Submit answers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoworkComposer extends StatelessWidget {
  const _CoworkComposer({
    required this.controller,
    required this.enabled,
    required this.steering,
    required this.onSend,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onDictate,
    required this.isDictating,
    required this.isTranscribing,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool steering;
  final VoidCallback onSend;
  final List<SharedChatAttachment> attachments;
  final ValueChanged<SharedChatAttachment> onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onDictate;
  final bool isDictating;
  final bool isTranscribing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (attachments.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: attachments
                  .map(
                    (attachment) => InputChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 17),
                      label: Text(attachment.name),
                      onDeleted: () => onRemoveAttachment(attachment),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Attach files',
                onPressed: enabled ? onAttach : null,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              IconButton(
                tooltip: isDictating ? 'Stop dictation' : 'Dictate',
                onPressed: enabled && !isTranscribing ? onDictate : null,
                color: isDictating ? Theme.of(context).colorScheme.error : null,
                icon: isTranscribing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isDictating
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                      ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 7,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: steering
                        ? 'Steer the active run…'
                        : 'Message NeoAgent…',
                    helperText: steering
                        ? 'This message will steer the current run.'
                        : 'Use the arrow to send; Enter adds a line.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    suffixIcon: IconButton(
                      tooltip: steering ? 'Steer run' : 'Send',
                      onPressed: enabled ? onSend : null,
                      icon: Icon(
                        steering
                            ? Icons.alt_route_rounded
                            : Icons.arrow_upward_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _coworkMimeTypeForFileName(String fileName) {
  switch (fileName.split('.').last.toLowerCase()) {
    case 'jpg' || 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'pdf':
      return 'application/pdf';
    case 'txt' || 'md' || 'log':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

class _CoworkWorkSurface extends StatefulWidget {
  const _CoworkWorkSurface({required this.controller});

  final NeoAgentController controller;

  @override
  State<_CoworkWorkSurface> createState() => _CoworkWorkSurfaceState();
}

class _CoworkWorkSurfaceState extends State<_CoworkWorkSurface> {
  String? _lastChatId;
  String? _lastSurfaceKey;

  NeoAgentController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final selectedChat = controller.selectedCoworkChat;
    if (selectedChat == null) {
      return const _CoworkEmpty(
        icon: Icons.desktop_windows_outlined,
        title: 'Computer',
        message: 'Select a chat to see its computer.',
      );
    }
    var chat = selectedChat;
    if (controller.coworkWorkSurfacePinned && _lastChatId != null) {
      for (final candidate in controller.coworkChats) {
        if (candidate.id == _lastChatId) {
          chat = candidate;
          break;
        }
      }
    } else {
      _lastChatId = selectedChat.id;
    }
    if (_lastChatId != chat.id) {
      _lastChatId = chat.id;
    }
    final surfaceKey = '${chat.id}:${chat.device.effective}';
    if (_lastSurfaceKey != surfaceKey) {
      _lastSurfaceKey = surfaceKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            controller.refreshDevices(deviceTarget: chat.device.effective),
          );
        }
      });
    }
    final local = chat.device.effective == 'local';
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          child: Row(
            children: <Widget>[
              Icon(
                local ? Icons.laptop_mac_rounded : Icons.cloud_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${local ? 'This device' : 'Cloud computer'} · ${chat.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: controller.coworkWorkSurfacePinned
                    ? 'Follow the selected chat'
                    : 'Keep this chat computer visible',
                onPressed: () => controller.setCoworkWorkSurfacePinned(
                  !controller.coworkWorkSurfacePinned,
                ),
                icon: Icon(
                  controller.coworkWorkSurfacePinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DevicesPanel(
            key: ValueKey<String>('${chat.id}:${chat.device.effective}'),
            controller: controller,
            deviceTarget: chat.device.effective,
            showProviderPicker: false,
            computerOnly: true,
          ),
        ),
      ],
    );
  }
}

class _CoworkStatusDot extends StatelessWidget {
  const _CoworkStatusDot({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalized = status ?? '';
    final color = normalized == 'failed'
        ? Theme.of(context).colorScheme.error
        : normalized == 'paused' || normalized == 'waiting_input'
        ? Colors.amber
        : <String>{
            'pending',
            'running',
            'pausing',
            'resuming',
          }.contains(normalized)
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CoworkEmpty extends StatelessWidget {
  const _CoworkEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
