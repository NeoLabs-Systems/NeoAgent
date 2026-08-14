part of 'main.dart';

const double _coworkCompactWidth = 760;
const double _coworkWideWidth = 1080;

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
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      blurSigma: 18,
      fillColor: _bgCard.withValues(alpha: 0.88),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CoworkSegPill(
            selected: !controller.desktopCoworkMode,
            icon: Icons.dashboard_outlined,
            label: 'Standard',
            onTap: () => controller.setDesktopCoworkMode(false),
          ),
          _CoworkSegPill(
            selected: controller.desktopCoworkMode,
            leading: _LogoBadge(size: 14),
            label: 'Cowork',
            onTap: () => controller.setDesktopCoworkMode(true),
          ),
        ],
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
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  List<SharedChatAttachment> _attachments = const <SharedChatAttachment>[];
  LiveVoiceCapture? _dictationCapture;
  final List<Uint8List> _dictationChunks = <Uint8List>[];
  bool _isDictating = false;
  bool _isTranscribing = false;
  bool _showChats = false;
  bool _showComputer = false;

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
    _composerFocus.dispose();
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
    FocusScope.of(context).requestFocus(_composerFocus);
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
    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < _coworkCompactWidth;
              final wide = constraints.maxWidth >= _coworkWideWidth;
              final showRail = !compact;
              final showComputer = wide || (_showComputer && !wide);
              final chatsWidth = constraints.maxWidth >= 1450 ? 280.0 : 236.0;
              final computerWidth = wide
                  ? (constraints.maxWidth * 0.36).clamp(420.0, 620.0)
                  : constraints.maxWidth;
              return Column(
                children: <Widget>[
                  _CoworkTopBar(
                    controller: controller,
                    compact: compact,
                    computerOpen: showComputer,
                    onToggleChats: compact
                        ? () => setState(() => _showChats = !_showChats)
                        : null,
                    onToggleComputer: wide
                        ? null
                        : () => setState(() => _showComputer = !_showComputer),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 10 : 14,
                        0,
                        compact ? 10 : 14,
                        compact ? 10 : 14,
                      ),
                      child: Stack(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (showRail) ...<Widget>[
                                SizedBox(
                                  width: chatsWidth,
                                  child: _CoworkChatRail(controller: controller),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: _CoworkConversation(
                                  controller: controller,
                                  composer: _composer,
                                  composerFocus: _composerFocus,
                                  scrollController: _scroll,
                                  onSend: _send,
                                  attachments: _attachments,
                                  onRemoveAttachment: (attachment) =>
                                      setState(() {
                                        _attachments = _attachments
                                            .where(
                                              (item) => item != attachment,
                                            )
                                            .toList(growable: false);
                                      }),
                                  onAttach: _attachFiles,
                                  onDictate: _toggleDictation,
                                  isDictating: _isDictating,
                                  isTranscribing: _isTranscribing,
                                  compact: compact,
                                ),
                              ),
                              if (wide) ...<Widget>[
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: computerWidth,
                                  child: _CoworkWorkSurface(
                                    controller: controller,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (compact && _showChats)
                            _CoworkScrimPanel(
                              alignment: Alignment.centerLeft,
                              width: math.min(320, constraints.maxWidth * 0.86),
                              onDismiss: () =>
                                  setState(() => _showChats = false),
                              child: _CoworkChatRail(
                                controller: controller,
                                onSelect: () =>
                                    setState(() => _showChats = false),
                                onClose: () =>
                                    setState(() => _showChats = false),
                              ),
                            ),
                          if (!wide && _showComputer)
                            _CoworkScrimPanel(
                              alignment: Alignment.centerRight,
                              width: math.min(computerWidth, constraints.maxWidth),
                              onDismiss: () =>
                                  setState(() => _showComputer = false),
                              child: _CoworkWorkSurface(
                                controller: controller,
                                onClose: () =>
                                    setState(() => _showComputer = false),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoworkScrimPanel extends StatelessWidget {
  const _CoworkScrimPanel({
    required this.alignment,
    required this.width,
    required this.onDismiss,
    required this.child,
  });

  final Alignment alignment;
  final double width;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
          ),
        ),
        Align(
          alignment: alignment,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoworkTopBar extends StatelessWidget {
  const _CoworkTopBar({
    required this.controller,
    required this.compact,
    required this.computerOpen,
    this.onToggleChats,
    this.onToggleComputer,
  });

  final NeoAgentController controller;
  final bool compact;
  final bool computerOpen;
  final VoidCallback? onToggleChats;
  final VoidCallback? onToggleComputer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 10, compact ? 12 : 18, 10),
      child: Row(
        children: <Widget>[
          if (onToggleChats != null) ...<Widget>[
            _CoworkIconChip(
              tooltip: 'Chats',
              icon: Icons.forum_outlined,
              onPressed: onToggleChats!,
            ),
            const SizedBox(width: 10),
          ],
          const _LogoBadge(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'NeoAgent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.geist(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Cowork',
                  style: _sectionEyebrowStyle(),
                ),
              ],
            ),
          ),
          if (!controller.socketConnected) ...<Widget>[
            const _CoworkLiveDot(connected: false),
            const SizedBox(width: 10),
          ],
          if (onToggleComputer != null) ...<Widget>[
            _CoworkIconChip(
              tooltip: computerOpen ? 'Hide computer' : 'Show computer',
              icon: computerOpen
                  ? Icons.desktop_windows_rounded
                  : Icons.desktop_windows_outlined,
              selected: computerOpen,
              onPressed: onToggleComputer!,
            ),
            const SizedBox(width: 8),
          ],
          if (!compact) _DesktopModeSwitch(controller: controller),
          if (compact)
            _CoworkIconChip(
              tooltip: 'Standard view',
              icon: Icons.dashboard_outlined,
              onPressed: () => controller.setDesktopCoworkMode(false),
            ),
        ],
      ),
    );
  }
}

class _CoworkLiveDot extends StatelessWidget {
  const _CoworkLiveDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (connected ? _success : _danger).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: (connected ? _success : _danger).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? _success : _danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Live' : 'Offline',
            style: GoogleFonts.geistMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: connected ? _success : _danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoworkIconChip extends StatelessWidget {
  const _CoworkIconChip({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? _accentMuted : _bgCard.withValues(alpha: 0.72),
        shape: CircleBorder(
          side: BorderSide(color: selected ? _accent : _borderLight),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: selected ? _accent : _textSecondary),
          ),
        ),
      ),
    );
  }
}

class _CoworkSegPill extends StatelessWidget {
  const _CoworkSegPill({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
  });

  final bool selected;
  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = leading ??
        (icon == null
            ? null
            : Icon(
                icon,
                size: 15,
                color: selected ? _bgPrimary : _textSecondary,
              ));
    return Material(
      color: selected ? _accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (mark != null) ...<Widget>[
                mark,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? _bgPrimary : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoworkChatRail extends StatelessWidget {
  const _CoworkChatRail({
    required this.controller,
    this.onSelect,
    this.onClose,
  });

  final NeoAgentController controller;
  final VoidCallback? onSelect;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text('SESSIONS', style: _sectionEyebrowStyle())),
                    if (onClose != null)
                      _CoworkIconChip(
                        tooltip: 'Close',
                        icon: Icons.close_rounded,
                        onPressed: onClose!,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      unawaited(controller.createCoworkChat());
                      onSelect?.call();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New chat'),
                  ),
                ),
              ],
            ),
          ),
          if (controller.isLoadingCowork && controller.coworkChats.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.coworkChats.isEmpty)
            const Expanded(
              child: _CoworkEmpty(
                title: 'No sessions yet',
                message: 'Start a chat to plan or build with NeoAgent.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
                itemCount: controller.coworkChats.length,
                itemBuilder: (context, index) {
                  final chat = controller.coworkChats[index];
                  final selected = chat.id == controller.selectedCoworkChatId;
                  final thread = controller.coworkThreadFor(chat.id);
                  final status = thread.runStatus ?? chat.latestRun?.status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: selected ? _accentMuted : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          controller.selectCoworkChat(chat.id);
                          onSelect?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _accent.withValues(alpha: 0.35) : Colors.transparent,
                            ),
                          ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${chat.agentName} · ${chat.mode == CoworkInteractionMode.plan ? 'Plan' : 'Agent'} · ${chat.device.effective == 'local' ? 'This device' : 'Cloud'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.geistMono(
                                        fontSize: 10.5,
                                        color: _textMuted,
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
    required this.composerFocus,
    required this.scrollController,
    required this.onSend,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onDictate,
    required this.isDictating,
    required this.isTranscribing,
    required this.compact,
  });

  final NeoAgentController controller;
  final TextEditingController composer;
  final FocusNode composerFocus;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final List<SharedChatAttachment> attachments;
  final ValueChanged<SharedChatAttachment> onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onDictate;
  final bool isDictating;
  final bool isTranscribing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chat = controller.selectedCoworkChat;
    final thread = controller.selectedCoworkThread;
    if (chat == null) {
      return _GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: const _CoworkEmpty(
          title: 'Choose a session',
          message: 'Create or select a Cowork chat to begin.',
        ),
      );
    }
    final pending = thread.inputRequests
        .where((item) => item.isPending)
        .toList();
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgCard.withValues(alpha: 0.62),
      child: Column(
        children: <Widget>[
          _CoworkChatHeader(
            controller: controller,
            chat: chat,
            thread: thread,
            compact: compact,
          ),
          if (thread.hasLiveRun || thread.phase.isNotEmpty)
            _CoworkActivitySummary(thread: thread),
          Expanded(
            child: thread.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 28,
                      18,
                      compact ? 16 : 28,
                      16,
                    ),
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
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: FilledButton.icon(
                              onPressed: controller.implementSelectedCoworkPlan,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Implement plan'),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _CoworkComposer(
            controller: composer,
            focusNode: composerFocus,
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
      ),
    );
  }
}

class _CoworkChatHeader extends StatelessWidget {
  const _CoworkChatHeader({
    required this.controller,
    required this.chat,
    required this.thread,
    required this.compact,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final CoworkThreadState thread;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final agents = controller.agentProfiles
        .where((agent) => agent.status != 'archived')
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 12, compact ? 10 : 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (thread.hasLiveRun) ...<Widget>[
                _CoworkIconChip(
                  tooltip: thread.runStatus == 'paused' ? 'Resume' : 'Pause',
                  icon: thread.runStatus == 'paused'
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: thread.runStatus == 'paused'
                      ? controller.resumeCoworkRun
                      : controller.pauseCoworkRun,
                ),
                const SizedBox(width: 6),
                _CoworkIconChip(
                  tooltip: 'Stop',
                  icon: Icons.stop_rounded,
                  onPressed: controller.stopCoworkRun,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _CoworkMenuPill(
                icon: Icons.person_outline_rounded,
                label: agents
                    .where((agent) => agent.id == chat.agentId)
                    .map((agent) => agent.displayName)
                    .firstOrNull ??
                    chat.agentName,
                items: agents
                    .map(
                      (agent) => PopupMenuItem<String>(
                        value: agent.id,
                        child: Text(agent.displayName),
                      ),
                    )
                    .toList(growable: false),
                onSelected: (value) => controller.updateCoworkChat(
                  chat.id,
                  <String, dynamic>{'agentId': value},
                ),
              ),
              _GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                fillColor: _bgSecondary.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _CoworkSegPill(
                      selected: chat.mode == CoworkInteractionMode.agent,
                      icon: Icons.play_arrow_rounded,
                      label: 'Agent',
                      onTap: () => controller.updateCoworkChat(
                        chat.id,
                        const <String, dynamic>{'mode': 'agent'},
                      ),
                    ),
                    _CoworkSegPill(
                      selected: chat.mode == CoworkInteractionMode.plan,
                      icon: Icons.route_outlined,
                      label: 'Plan',
                      onTap: () => controller.updateCoworkChat(
                        chat.id,
                        const <String, dynamic>{'mode': 'plan'},
                      ),
                    ),
                  ],
                ),
              ),
              _CoworkDeviceMenu(controller: controller, chat: chat),
              if (chat.device.effective == 'local')
                _CoworkWorkspaceMenu(controller: controller, chat: chat),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoworkMenuPill extends StatelessWidget {
  const _CoworkMenuPill({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<PopupMenuItem<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Agent',
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: _CoworkOutlinePill(icon: icon, label: label),
    );
  }
}

class _CoworkOutlinePill extends StatelessWidget {
  const _CoworkOutlinePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSecondary.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: _textSecondary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 16, color: _textMuted),
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
    final local = device.effective == 'local';
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
                ? 'This device'
                : 'This device — unavailable',
          ),
        ),
        PopupMenuItem<String>(
          value: 'cloud',
          enabled: device.cloudAvailable,
          child: const Text('Cloud computer'),
        ),
      ],
      child: _CoworkOutlinePill(
        icon: local ? Icons.laptop_mac_rounded : Icons.cloud_outlined,
        label: '${local ? 'This device' : 'Cloud'}${device.inherited ? ' · default' : ''}',
      ),
    );
  }
}

String _coworkWorkspaceLabel(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? path : segments.last;
}

class _CoworkWorkspaceMenu extends StatefulWidget {
  const _CoworkWorkspaceMenu({required this.controller, required this.chat});

  final NeoAgentController controller;
  final CoworkChat chat;

  @override
  State<_CoworkWorkspaceMenu> createState() => _CoworkWorkspaceMenuState();
}

class _CoworkWorkspaceMenuState extends State<_CoworkWorkspaceMenu> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _setOverride(String? path) async {
    await widget.controller.updateCoworkChat(
      widget.chat.id,
      <String, dynamic>{'workspacePathOverride': path},
    );
    if (path != null && path.trim().isNotEmpty) {
      await WorkspaceRecents.recordUsed(path.trim());
    }
  }

  Future<void> _browseForFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a workspace folder',
    );
    if (chosen == null || chosen.trim().isEmpty) return;
    await _setOverride(chosen.trim());
  }

  Future<void> _openMenu() async {
    final recents = (await WorkspaceRecents.list())
        .where((path) => path != widget.chat.workspacePathOverride)
        .toList(growable: false);
    if (!mounted) return;
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: '__default__',
          child: Text('Use default (NeoAgent Workspace)'),
        ),
        const PopupMenuItem<String>(
          value: '__browse__',
          child: Text('Choose folder…'),
        ),
        if (recents.isNotEmpty) const PopupMenuDivider(),
        for (final path in recents)
          PopupMenuItem<String>(
            value: path,
            child: Text(
              _coworkWorkspaceLabel(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected == '__browse__') {
      await _browseForFolder();
      return;
    }
    await _setOverride(selected == '__default__' ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.chat.workspacePathOverride;
    return Material(
      key: _anchorKey,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: _openMenu,
        child: _CoworkOutlinePill(
          icon: Icons.folder_outlined,
          label: override == null
              ? 'NeoAgent Workspace'
              : _coworkWorkspaceLabel(override),
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
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        decoration: BoxDecoration(
          color: _bgSecondary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          leading: thread.hasLiveRun
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                )
              : Icon(Icons.check_circle_outline, size: 18, color: _success),
          title: Text(
            thread.phase.ifEmpty('Activity'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          subtitle: latest == null
              ? null
              : Text(
                  '${latest.label} · ${latest.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.geistMono(fontSize: 11, color: _textMuted),
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
                      color: item.status == 'failed'
                          ? _danger
                          : item.status == 'running'
                          ? _accent
                          : _success,
                    ),
                    title: Text(item.label),
                    subtitle: Text(
                      item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.durationMs == null
                        ? null
                        : Text(
                            '${item.durationMs} ms',
                            style: GoogleFonts.geistMono(
                              fontSize: 11,
                              color: _textMuted,
                            ),
                          ),
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

class _CoworkMessageBubble extends StatelessWidget {
  const _CoworkMessageBubble({required this.message});

  final ChatEntry message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final interim = message.metadata['interim'] == true;
    final attachments = _jsonMapList(message.metadata['sharedAttachments']);
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            color: user
                ? _accentMuted
                : interim
                ? _accentAlt.withValues(alpha: 0.12)
                : _bgSecondary.withValues(alpha: 0.82),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(user ? 18 : 6),
              bottomRight: Radius.circular(user ? 6 : 18),
            ),
            border: Border.all(
              color: user ? _accent.withValues(alpha: 0.22) : _border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!user)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _LogoBadge(size: 14),
                      const SizedBox(width: 6),
                      Text(
                        interim
                            ? 'Status'
                            : (message.senderName?.ifEmpty('NeoAgent') ??
                                  'NeoAgent'),
                        style: GoogleFonts.geist(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (user)
                SelectableText(
                  message.content,
                  style: TextStyle(color: _textPrimary, height: 1.5),
                )
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
                          backgroundColor: _bgTertiary,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: _bgTertiary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
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
                    style: GoogleFonts.geistMono(fontSize: 11, color: _textMuted),
                  ),
                ),
            ],
          ),
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
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.card),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('NEOAGENT NEEDS INPUT', style: _sectionEyebrowStyle()),
          const SizedBox(height: 8),
          Text(
            'Answer to keep the run moving.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          for (final question in widget.request.questions) ...<Widget>[
            Text(
              question.header,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(question.question, style: TextStyle(color: _textSecondary)),
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
    );
  }
}

class _CoworkComposer extends StatelessWidget {
  const _CoworkComposer({
    required this.controller,
    required this.focusNode,
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
  final FocusNode focusNode;
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _borderLight),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _ChatComposerIconButton(
                  tooltip: 'Attach files',
                  icon: Icons.attach_file_rounded,
                  onPressed: enabled ? onAttach : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                          enabled ? onSend : () {},
                      const SingleActivator(LogicalKeyboardKey.enter, control: true):
                          enabled ? onSend : () {},
                    },
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: steering
                            ? 'Steer the active run…'
                            : 'Message NeoAgent…',
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                isTranscribing
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _ChatComposerIconButton(
                        tooltip: isDictating ? 'Stop dictation' : 'Dictate',
                        icon: isDictating
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none_rounded,
                        color: isDictating
                            ? Theme.of(context).colorScheme.error
                            : null,
                        onPressed: enabled && !isTranscribing ? onDictate : null,
                      ),
                const SizedBox(width: 6),
                _ChatComposerIconButton(
                  tooltip: steering ? 'Steer run' : 'Send',
                  icon: steering
                      ? Icons.alt_route_rounded
                      : Icons.north_east_rounded,
                  color: Colors.white,
                  backgroundColor: _accent,
                  onPressed: enabled ? onSend : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            steering
                ? 'This steers the current run. ⌘↵ / Ctrl↵ to send.'
                : 'Enter for a new line. ⌘↵ / Ctrl↵ to send.',
            style: GoogleFonts.geistMono(fontSize: 11, color: _textMuted),
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
  const _CoworkWorkSurface({required this.controller, this.onClose});

  final NeoAgentController controller;
  final VoidCallback? onClose;

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
      return _GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: const _CoworkEmpty(
          title: 'Computer',
          message: 'Select a chat to see its computer.',
        ),
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
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: <Widget>[
                Icon(
                  local ? Icons.laptop_mac_rounded : Icons.cloud_outlined,
                  size: 18,
                  color: _accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('COMPUTER', style: _sectionEyebrowStyle()),
                      Text(
                        '${local ? 'This device' : 'Cloud computer'} · ${chat.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
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
                    color: controller.coworkWorkSurfacePinned
                        ? _accent
                        : _textSecondary,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close_rounded, color: _textSecondary),
                  ),
              ],
            ),
          ),
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
      ),
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
        ? _danger
        : normalized == 'paused' || normalized == 'waiting_input'
        ? _warning
        : <String>{
            'pending',
            'running',
            'pausing',
            'resuming',
          }.contains(normalized)
        ? _success
        : _textMuted;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CoworkEmpty extends StatelessWidget {
  const _CoworkEmpty({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _LogoBadge(size: 44),
            const SizedBox(height: 16),
            Text(title, style: _displayTitleStyle(20)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
