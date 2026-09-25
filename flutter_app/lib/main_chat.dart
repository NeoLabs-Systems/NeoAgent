part of 'main.dart';

/// Prompt starters offered on the empty chat screen. Tapping one types it
/// into the composer — it never sends on its own, so the user still edits and
/// presses send.
typedef _ChatStarter = ({IconData icon, String prompt, String caption});

const List<_ChatStarter> _promptStarters = <_ChatStarter>[
  (
    icon: Icons.restart_alt_rounded,
    prompt: 'Summarise my last run',
    caption: 'Picks up where you left off',
  ),
  (
    icon: Icons.event_outlined,
    prompt: 'What is on tomorrow?',
    caption: 'Pulls together the day ahead',
  ),
];

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> with WidgetsBindingObserver {
  static const double _autoScrollBottomThreshold = 120;
  static const double _stickResumeThreshold = 8;
  static const double _olderHistoryLoadThreshold = 180;
  static const int _initialSettleFrameBudget = 120;

  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();
  List<SharedChatAttachment> _pendingSharedAttachments =
      const <SharedChatAttachment>[];
  String? _appliedSharedPayloadSignature;
  String _lastScrollContentSignature = '';
  bool _stickToBottom = true;
  bool _ignoreScrollUpdates = false;

  /// True from the moment a drag begins until its momentum settles. Auto-follow
  /// never re-pins while this is set.
  bool _userScrollActive = false;
  bool _loadingOlderHistory = false;
  int _scrollGeneration = 0;
  // Opacity-hide the list while the initial batch of messages settles to the
  // bottom, so the user never sees the layout jitter across settle passes.
  bool _awaitingInitialScrollSettle = false;
  int _visibleMessageCountAtLastSettle = 0;
  bool _isSendingChatMessage = false;
  bool _isDictating = false;
  bool _isTranscribing = false;
  LiveVoiceCapture? _dictationCapture;
  final List<Uint8List> _dictationChunks = [];
  Timer? _connectionBannerTimer;
  bool _showConnectionBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerController = TextEditingController();
    _composerController.addListener(_handleComposerLayoutChanged);
    _scrollController.addListener(_handleScrollPositionChanged);
    widget.controller.addListener(_consumeQueuedDraft);
    widget.controller.addListener(_updateConnectionBanner);
    _consumeQueuedDraft();
    _scheduleScrollToBottom(force: true);
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_consumeQueuedDraft);
      oldWidget.controller.removeListener(_updateConnectionBanner);
      widget.controller.addListener(_consumeQueuedDraft);
      widget.controller.addListener(_updateConnectionBanner);
      _appliedSharedPayloadSignature = null;
      _lastScrollContentSignature = '';
      _stickToBottom = true;
      _awaitingInitialScrollSettle = false;
      _visibleMessageCountAtLastSettle = 0;
      _consumeQueuedDraft();
      _scheduleScrollToBottom(force: true);
    }
  }

  void _updateConnectionBanner() {
    final connected = widget.controller.socketConnected;
    if (connected) {
      _connectionBannerTimer?.cancel();
      _connectionBannerTimer = null;
      if (_showConnectionBanner) {
        setState(() => _showConnectionBanner = false);
      }
    } else if (!_showConnectionBanner && !widget.controller.isBooting) {
      // ??= keeps the first timer alive; repeated disconnect events don't reset the 2s clock.
      _connectionBannerTimer ??= Timer(const Duration(seconds: 2), () {
        if (mounted && !widget.controller.socketConnected) {
          setState(() => _showConnectionBanner = true);
        }
        _connectionBannerTimer = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_consumeQueuedDraft);
    widget.controller.removeListener(_updateConnectionBanner);
    _composerController.removeListener(_handleComposerLayoutChanged);
    _scrollController.removeListener(_handleScrollPositionChanged);
    _composerController.dispose();
    _scrollController.dispose();
    _dictationCapture?.dispose();
    _connectionBannerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  Future<void> _startDictation() async {
    if (_isDictating || _isTranscribing) return;
    final capture = LiveVoiceCapture();
    _dictationCapture = capture;
    _dictationChunks.clear();
    try {
      await capture.start(
        onChunk: (chunk) => _dictationChunks.add(chunk),
        sampleRate: 16000,
        channels: 1,
      );
      if (mounted) setState(() => _isDictating = true);
    } catch (e) {
      await capture.dispose();
      _dictationCapture = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Microphone error: $e')));
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_isDictating) return;
    final capture = _dictationCapture;
    _dictationCapture = null;
    setState(() {
      _isDictating = false;
      _isTranscribing = true;
    });
    try {
      await capture?.stop();
      if (_dictationChunks.isEmpty) return;
      final allBytes = _dictationChunks.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      final audioBase64 = base64Encode(Uint8List.fromList(allBytes));
      final transcript = await widget.controller.transcribeDictationAudio(
        audioBase64: audioBase64,
      );
      if (mounted && transcript.isNotEmpty) {
        final current = _composerController.text;
        final separator = current.isNotEmpty && !current.endsWith(' ')
            ? ' '
            : '';
        _composerController.text = '$current$separator$transcript';
        _composerController.selection = TextSelection.collapsed(
          offset: _composerController.text.length,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    } finally {
      await capture?.dispose();
      _dictationChunks.clear();
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  void _consumeQueuedDraft() {
    final draft = widget.controller.peekPendingChatDraft();
    final attachments = widget.controller.peekPendingSharedChatAttachments();
    final signature = _sharedPayloadSignature(draft, attachments);
    if (draft == null && attachments.isEmpty) {
      return;
    }
    if (_appliedSharedPayloadSignature == signature) {
      return;
    }
    _appliedSharedPayloadSignature = signature;
    if (!mounted) {
      return;
    }
    setState(() {
      if ((draft ?? '').isNotEmpty && _composerController.text.trim().isEmpty) {
        _composerController
          ..text = draft!
          ..selection = TextSelection.collapsed(offset: draft.length);
      }
      _pendingSharedAttachments = attachments;
    });
  }

  String _sharedPayloadSignature(
    String? draft,
    List<SharedChatAttachment> attachments,
  ) {
    final attachmentSignature = attachments
        .map((item) => '${item.uri}|${item.name}|${item.mimeType}')
        .join('::');
    return '${draft ?? ''}::$attachmentSignature';
  }

  void _clearSharedPayload() {
    widget.controller.clearPendingSharedChatPayload();
    _appliedSharedPayloadSignature = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingSharedAttachments = const <SharedChatAttachment>[];
    });
    if (_stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  String _mimeTypeForFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
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
      case 'm4v':
        return 'video/x-m4v';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  void _useStarter(String prompt) {
    _composerController.text = prompt;
    _composerController.selection = TextSelection.collapsed(
      offset: prompt.length,
    );
  }

  Future<void> _attachFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.any,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final attachments = result.files
        .where(
          (file) => kIsWeb
              ? file.bytes != null
              : file.path?.trim().isNotEmpty == true,
        )
        .map(
          (file) => SharedChatAttachment(
            uri: kIsWeb ? file.name : file.path!,
            name: file.name,
            mimeType: _mimeTypeForFileName(file.name),
            sizeBytes: file.size,
            source: 'file_picker',
          ),
        )
        .where((item) => item.isValid)
        .toList(growable: false);
    if (attachments.isEmpty) {
      return;
    }
    setState(() {
      _pendingSharedAttachments = <SharedChatAttachment>[
        ..._pendingSharedAttachments,
        ...attachments,
      ];
    });
    if (_stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  // Re-pin to the bottom whenever the content grows underneath us (late
  // markdown layout, images, expanding step boxes, streaming chunks). Growth
  // only moves maxScrollExtent, never pixels, so the scroll-position listener
  // alone never sees it.
  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    if (_ignoreScrollUpdates ||
        _userScrollActive ||
        !_stickToBottom ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _pinToBottom();
    return false;
  }

  // A user scroll always wins over auto-follow, from the first pixel — drag,
  // trackpad, mouse wheel, or scrollbar. The near-bottom band is only a
  // follow heuristic for new content, not a dead zone the user has to escape.
  bool _handleUserScroll(ScrollNotification notification) {
    if (_ignoreScrollUpdates || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        _finishUserScroll();
      } else {
        // Forward = toward older messages (offset shrinks). Reverse keeps
        // follow suppressed for the gesture without flashing the jump button.
        _beginUserScroll(
          unstick: notification.direction == ScrollDirection.forward,
        );
      }
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _beginUserScroll(unstick: true);
    } else if (notification is ScrollEndNotification) {
      _finishUserScroll();
    }
    return false;
  }

  void _beginUserScroll({required bool unstick}) {
    _userScrollActive = true;
    // Cancels any in-flight settle pass, which re-asserts _stickToBottom.
    _scrollGeneration++;
    if (unstick && (_stickToBottom || _awaitingInitialScrollSettle)) {
      setState(() {
        _stickToBottom = false;
        _awaitingInitialScrollSettle = false;
      });
    }
  }

  void _finishUserScroll() {
    if (!_userScrollActive) return;
    _userScrollActive = false;
    // Resume follow only when they actually landed on the last pixel, not
    // merely inside the 120px near-bottom band they were trying to leave.
    final atBottom = _isAtBottom;
    if (_stickToBottom != atBottom) {
      setState(() => _stickToBottom = atBottom);
    }
  }

  void _pinToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userScrollActive || !_stickToBottom) return;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if ((position.pixels - position.maxScrollExtent).abs() <= 0.5) return;
      _ignoreScrollUpdates = true;
      _scrollController.jumpTo(position.maxScrollExtent);
      _ignoreScrollUpdates = false;
    });
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return true;
    return pos.pixels >= pos.maxScrollExtent - _autoScrollBottomThreshold;
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return true;
    return pos.pixels >= pos.maxScrollExtent - _stickResumeThreshold;
  }

  bool get _isNearTop {
    if (!_scrollController.hasClients) return false;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return false;
    return pos.pixels <= _olderHistoryLoadThreshold;
  }

  void _handleScrollPositionChanged() {
    if (_ignoreScrollUpdates || !_scrollController.hasClients) return;
    if (_isNearTop) {
      unawaited(_maybeLoadOlderHistory());
    }
    if (_userScrollActive) return;
    // Only release the pin here — never re-stick from a still-near-bottom
    // offset. That two-way sync fought the user's first 120px of travel.
    if (_stickToBottom && !_isNearBottom) {
      _scrollGeneration++;
      setState(() => _stickToBottom = false);
    }
  }

  Future<void> _maybeLoadOlderHistory() async {
    final controller = widget.controller;
    if (_loadingOlderHistory ||
        controller.isLoadingOlderChatHistory ||
        !controller.chatHistoryHasMore ||
        !_isNearTop) {
      return;
    }
    _loadingOlderHistory = true;
    final hasClients = _scrollController.hasClients;
    final previousPixels = hasClients ? _scrollController.position.pixels : 0.0;
    final previousMaxExtent = hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final loaded = await controller.loadOlderChatHistory();
    if (!mounted || !loaded) {
      _loadingOlderHistory = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _loadingOlderHistory = false;
        return;
      }
      final position = _scrollController.position;
      final extentDelta = position.maxScrollExtent - previousMaxExtent;
      final targetOffset = (previousPixels + extentDelta).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _ignoreScrollUpdates = true;
      _scrollController.jumpTo(targetOffset.toDouble());
      _ignoreScrollUpdates = false;
      _loadingOlderHistory = false;
      if (_isNearTop) {
        unawaited(_maybeLoadOlderHistory());
      }
    });
  }

  void _openModelPicker() {
    final controller = widget.controller;
    if (controller.hasLiveRun) return;
    final models = controller.supportedModels
        .where((m) => m.available)
        .toList();
    final options = _modelPickerOptions(models, allowAuto: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 230),
      transitionBuilder: (ctx, animation, secondary, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
      pageBuilder: (dialogContext, _, __) => _ModelPickerDialog(
        title: 'Chat Model',
        options: options,
        currentValue: controller.defaultChatModel,
        onChanged: (v) {
          Navigator.of(dialogContext).pop();
          controller.saveSettingsPayload({'default_chat_model': v});
        },
      ),
    );
  }

  void _handleComposerLayoutChanged() {
    if (_stickToBottom) {
      _scheduleScrollToBottom();
    }
  }

  String _scrollContentSignature(
    List<ChatEntry> messages,
    NeoAgentController controller,
  ) {
    final last = messages.isEmpty ? null : messages.last;
    final activeRun = controller.activeRun;
    return <Object?>[
      messages.length,
      last?.id,
      last?.role,
      last?.content.length,
      last?.typing,
      activeRun?.runId,
      controller.streamingAssistant.length,
      controller.isSendingMessage,
    ].join('|');
  }

  void _scheduleScrollToBottom({bool force = false}) {
    if (!force && !_stickToBottom) return;
    final generation = ++_scrollGeneration;

    if (_awaitingInitialScrollSettle) {
      // Frame-by-frame stability detection: keep jumping and checking until
      // maxScrollExtent is the same two frames in a row, then reveal. Each pass
      // requests the next frame itself, otherwise a batch that lays out in one
      // go would leave the thread hidden with no further frame to wake it.
      double? prevExtent;
      void settleInitial(int framesLeft) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              generation != _scrollGeneration ||
              !_scrollController.hasClients) {
            return;
          }
          final pos = _scrollController.position;
          double? currentExtent;
          if (pos.hasContentDimensions) {
            currentExtent = pos.maxScrollExtent;
            _ignoreScrollUpdates = true;
            _scrollController.jumpTo(currentExtent);
            _ignoreScrollUpdates = false;
          }
          _stickToBottom = true;
          final stable = currentExtent != null && currentExtent == prevExtent;
          prevExtent = currentExtent;
          if (stable || framesLeft <= 0) {
            if (_awaitingInitialScrollSettle) {
              setState(() {
                _awaitingInitialScrollSettle = false;
                _visibleMessageCountAtLastSettle =
                    widget.controller.visibleChatMessages.length;
              });
            }
            return;
          }
          settleInitial(framesLeft - 1);
        });
        WidgetsBinding.instance.scheduleFrame();
      }

      settleInitial(_initialSettleFrameBudget);
      return;
    }

    // Content is already visible: a single jump is enough here, because any
    // later growth re-pins through the scroll metrics listener.
    _stickToBottom = true;
    _pinToBottom();
  }

  void _maybeFollowChatContent(
    List<ChatEntry> messages,
    NeoAgentController controller,
  ) {
    final signature = _scrollContentSignature(messages, controller);
    if (_lastScrollContentSignature == signature) return;
    final isInitialContent = _lastScrollContentSignature.isEmpty;
    final shouldFollow = _stickToBottom || isInitialContent;
    _lastScrollContentSignature = signature;

    if (messages.isEmpty) {
      // Agent switch resets the settle tracker so the next batch triggers hiding.
      _visibleMessageCountAtLastSettle = 0;
    } else if (_visibleMessageCountAtLastSettle == 0 &&
        !_awaitingInitialScrollSettle) {
      // Messages just went from 0 → N: hide until the scroll position settles.
      _awaitingInitialScrollSettle = true;
    }

    if (shouldFollow) {
      _scheduleScrollToBottom(force: isInitialContent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final messages = controller.visibleChatMessages;
    _maybeFollowChatContent(messages, controller);

    final threadChildren = <Widget>[
      if (controller.isLoadingOlderChatHistory) ...<Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
      if (controller.usageAndLimits case final usage?
          when usage.hasLimits) ...<Widget>[
        _RateLimitStatusCard(usage: usage),
        const SizedBox(height: 16),
      ],
      if (controller.errorMessage != null) ...<Widget>[
        _InlineError(
          message: controller.errorMessage!,
          onDismiss: controller.clearInlineError,
        ),
        const SizedBox(height: 16),
      ],
      if (controller.activeRun != null || controller.toolEvents.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _RunStatusPanel(
            run: controller.activeRun,
            tools: controller.toolEvents,
          ),
        ),
      if (messages.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _GreetingHeader(
                subtitle:
                    'Runs, tools, memory, scheduling, skills, and MCP are all available here.',
              ),
              const SizedBox(height: 26),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = _promptStarters
                        .map(
                          (starter) => _PromptStarter(
                            icon: starter.icon,
                            prompt: starter.prompt,
                            caption: starter.caption,
                            onTap: () => _useStarter(starter.prompt),
                          ),
                        )
                        .toList(growable: false);
                    // Side by side once there is room for two readable
                    // cards; stacked on a phone.
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final card in cards) ...<Widget>[
                            card,
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (var i = 0; i < cards.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        )
      else
        ...messages.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _ChatBubble(
              entry: entry,
              onLoadRunDetail: controller.fetchRunDetail,
              onSendMessage: controller.sendMessage,
            ),
          ),
        ),
    ];

    Future<void> sendComposerMessage() async {
      final task = _composerController.text;
      if ((task.trim().isEmpty && _pendingSharedAttachments.isEmpty) ||
          _isSendingChatMessage) {
        return;
      }
      setState(() {
        _isSendingChatMessage = true;
      });
      _composerController.clear();
      final outgoingAttachments = _pendingSharedAttachments;
      _clearSharedPayload();
      try {
        await controller.sendMessage(
          task,
          sharedAttachments: outgoingAttachments,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSendingChatMessage = false;
          });
        }
      }
    }

    final sidePadding = _chatSidePadding(context);

    return Column(
      children: <Widget>[
        _ChatTopBar(controller: controller),
        Expanded(
          child: Stack(
            children: <Widget>[
              Opacity(
                opacity: _awaitingInitialScrollSettle ? 0.0 : 1.0,
                child: SelectionArea(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleUserScroll,
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _handleScrollMetrics,
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          30,
                          sidePadding,
                          18,
                        ),
                        children: <Widget>[
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: threadChildren,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!_stickToBottom)
                Positioned(
                  bottom: 14,
                  right: 16,
                  child: _ScrollToBottomButton(
                    onTap: () {
                      setState(() => _stickToBottom = true);
                      _scheduleScrollToBottom(force: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 16),
          decoration: BoxDecoration(
            color: _bgPrimary.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: <Widget>[
                  if (_showConnectionBanner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ConnectionReconnectingBanner(
                        hasNetwork: controller.hasNetworkConnection,
                      ),
                    ),
                  if (controller.pendingApproval != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PendingApprovalBanner(
                        approval: controller.pendingApproval!,
                      ),
                    ),
                  if (_pendingSharedAttachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SharedAttachmentTray(
                        attachments: _pendingSharedAttachments,
                        onRemoveAt: (index) {
                          setState(() {
                            _pendingSharedAttachments =
                                _pendingSharedAttachments
                                    .asMap()
                                    .entries
                                    .where((entry) => entry.key != index)
                                    .map((entry) => entry.value)
                                    .toList(growable: false);
                          });
                          if (_stickToBottom) {
                            _scheduleScrollToBottom();
                          }
                          if (_pendingSharedAttachments.isEmpty) {
                            _clearSharedPayload();
                          }
                        },
                        onClear: _clearSharedPayload,
                      ),
                    ),
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
                          onPressed: _attachFiles,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CallbackShortcuts(
                            bindings: <ShortcutActivator, VoidCallback>{
                              const SingleActivator(
                                LogicalKeyboardKey.enter,
                                meta: true,
                              ): _isSendingChatMessage
                                  ? () {}
                                  : sendComposerMessage,
                              const SingleActivator(
                                LogicalKeyboardKey.enter,
                                control: true,
                              ): _isSendingChatMessage
                                  ? () {}
                                  : sendComposerMessage,
                            },
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isTranscribing
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _ChatComposerIconButton(
                                tooltip: _isDictating
                                    ? 'Stop & transcribe'
                                    : 'Dictate',
                                icon: _isDictating
                                    ? Icons.stop_circle_outlined
                                    : Icons.mic_none_rounded,
                                color: _isDictating
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                                onPressed: _isDictating
                                    ? _stopAndTranscribe
                                    : _startDictation,
                              ),
                        const SizedBox(width: 6),
                        _ChatComposerIconButton(
                          tooltip: 'Call agent',
                          icon: Icons.call_rounded,
                          color: Colors.white,
                          backgroundColor: _success,
                          onPressed: () => controller.setSelectedSection(
                            AppSection.voiceAssistant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ChatComposerIconButton(
                          tooltip: 'Send',
                          icon: controller.hasLiveRun
                              ? Icons.alt_route_rounded
                              : Icons.north_east_rounded,
                          color: Colors.white,
                          backgroundColor: _accent,
                          onPressed: _isSendingChatMessage
                              ? null
                              : sendComposerMessage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: controller.hasLiveRun
                                    ? _success
                                    : _textMuted,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                controller.chatStatusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.geistMono(
                                  fontSize: 11.5,
                                  color: _textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: controller.hasLiveRun ? null : _openModelPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          constraints: const BoxConstraints(maxWidth: 200),
                          decoration: BoxDecoration(
                            color: _bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  controller.hasLiveRun
                                      ? 'Steering mode'
                                      : controller.modelIndicator,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.geistMono(
                                    fontSize: 11.5,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 13,
                                color: controller.hasLiveRun
                                    ? _textMuted
                                    : _textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RateLimitStatusCard extends StatelessWidget {
  const _RateLimitStatusCard({required this.usage});

  final AccountUsageAndLimits usage;

  Widget _buildWindow({
    required String label,
    required int usageAmount,
    required int? limit,
    required int remaining,
    required bool reached,
    required DateTime? recoversAt,
    required DateTime? fullResetAt,
  }) {
    if (limit == null || limit <= 0) return const SizedBox.shrink();
    final progress = (usageAmount / limit).clamp(0.0, 1.0);
    final color = reached
        ? _danger
        : progress >= 0.8
        ? _warning
        : _accent;
    final resetLabel = _usageWindowResetLabel(
      reached: reached,
      recoversAt: recoversAt,
      fullResetAt: fullResetAt,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              reached ? 'Limit reached' : '${_formatTokenCount(remaining)} left',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_formatTokenCount(usageAmount)} / ${_formatTokenCount(limit)} tokens'
          '${resetLabel == null ? '' : ' · $resetLabel'}',
          style: TextStyle(color: _textMuted, fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final windows = <Widget>[
      _buildWindow(
        label: '4-hour usage',
        usageAmount: usage.fourHourUsage,
        limit: usage.fourHourLimit,
        remaining: usage.fourHourRemaining,
        reached: usage.fourHourReached,
        recoversAt: usage.fourHourRecoversAt,
        fullResetAt: usage.fourHourFullResetAt,
      ),
      _buildWindow(
        label: '7-day usage',
        usageAmount: usage.weeklyUsage,
        limit: usage.weeklyLimit,
        remaining: usage.weeklyRemaining,
        reached: usage.weeklyReached,
        recoversAt: usage.weeklyRecoversAt,
        fullResetAt: usage.weeklyFullResetAt,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: usage.isReached ? _danger.withValues(alpha: 0.08) : _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: usage.isReached
              ? _danger.withValues(alpha: 0.55)
              : _borderLight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return Column(
              children: <Widget>[
                windows.first,
                const SizedBox(height: 14),
                windows.last,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: windows.first),
              const SizedBox(width: 24),
              Expanded(child: windows.last),
            ],
          );
        },
      ),
    );
  }
}

double _chatSidePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) return 40;
  if (width >= 900) return 30;
  return 20;
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: _chatSidePadding(context)),
      decoration: BoxDecoration(
        color: _bgPrimary.withValues(alpha: 0.72),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Chat',
            style: GoogleFonts.geist(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '/ ${controller.activeAgentLabel} / ${controller.modelIndicator}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.geistMono(fontSize: 11, color: _textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.hasLiveRun ? _success : _accentAlt,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (controller.hasLiveRun ? _success : _accentAlt)
                          .withValues(alpha: 0.18),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                controller.hasLiveRun ? 'live' : 'idle',
                style: GoogleFonts.geistMono(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatComposerIconButton extends StatelessWidget {
  const _ChatComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? _textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: onPressed == null
                  ? _bgTertiary.withValues(alpha: 0.52)
                  : backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
              color: onPressed == null ? _textMuted : foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scroll to bottom',
      child: Material(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: _textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedAttachmentTray extends StatelessWidget {
  const _SharedAttachmentTray({
    required this.attachments,
    required this.onRemoveAt,
    required this.onClear,
  });

  final List<SharedChatAttachment> attachments;
  final void Function(int index) onRemoveAt;
  final VoidCallback onClear;

  IconData _iconForMime(String mime) {
    final normalized = mime.toLowerCase();
    if (normalized.startsWith('image/')) return Icons.image_outlined;
    if (normalized.startsWith('video/')) return Icons.videocam_outlined;
    if (normalized.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (normalized.contains('pdf')) return Icons.picture_as_pdf_outlined;
    return Icons.attach_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
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
              Icon(Icons.forward_to_inbox_outlined, size: 15, color: _info),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shared from another app',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachments
                .asMap()
                .entries
                .map((entry) {
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _iconForMime(item.mimeType),
                          size: 14,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _textPrimary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onRemoveAt(entry.key),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ExcludeSemantics(
          child: NeoMascot(mood: MascotMood.thinking, size: 34),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(3, (index) {
                    final phase = ((_controller.value * 3) - index).clamp(
                      0.0,
                      1.0,
                    );
                    final offset = Curves.easeOut.transform(
                      phase > 0.5 ? 1 - phase : phase,
                    );
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == 2 ? 0 : 6,
                        top: (1 - offset) * 6,
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _textSecondary.withValues(
                            alpha: 0.45 + (offset * 0.5),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
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
        'Code Hosting',
        'Public issue and pull request threads, answered only for approved people.',
        ['github'],
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
        ['meshtastic'],
      ),
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
              'Connect channels, choose who ${controller.activeAgentLabel} talks to, and watch recent activity.',
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
                              onConnect: () => openMessagingConfig(
                                context,
                                controller,
                                platform,
                              ),
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
        if (controller.ignoredChats.isNotEmpty) ...[
          const SizedBox(height: 18),
          _IgnoredChatsPanel(controller: controller),
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
                    fontSize: 22,
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
                      tooltip: 'Clear search',
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

class _IgnoredChatsPanel extends StatelessWidget {
  const _IgnoredChatsPanel({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final ignored = controller.ignoredChats;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ignored Channels',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'These channels stay silent. To hear from them again, add them under Who can message for that platform.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: '${ignored.length}', color: _textMuted),
            ],
          ),
          const SizedBox(height: 14),
          for (final key in ignored)
            Builder(
              builder: (context) {
                final sep = key.indexOf(':');
                final platform = sep > 0 ? key.substring(0, sep) : key;
                final chatId = sep > 0 ? key.substring(sep + 1) : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, size: 16, color: _textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              platform.toUpperCase(),
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              chatId.isNotEmpty ? chatId : platform,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => controller.removeIgnoredChat(key),
                        child: Text('Remove'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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
                  message.content.trim().isEmpty
                      ? 'No message text'
                      : message.content,

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

// ─── Connection reconnecting banner (#65) ─────────────────────────────────

class _ConnectionReconnectingBanner extends StatelessWidget {
  const _ConnectionReconnectingBanner({required this.hasNetwork});

  final bool hasNetwork;

  @override
  Widget build(BuildContext context) {
    final msg = hasNetwork
        ? 'Reconnecting to server…'
        : 'No network connection';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          if (hasNetwork)
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _warning),
            )
          else
            Icon(Icons.wifi_off_outlined, size: 16, color: _warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: _warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending approval banner (#62) ────────────────────────────────────────

class _PendingApprovalBanner extends StatefulWidget {
  const _PendingApprovalBanner({required this.approval});

  final ToolApprovalRequest approval;

  @override
  State<_PendingApprovalBanner> createState() => _PendingApprovalBannerState();
}

class _PendingApprovalBannerState extends State<_PendingApprovalBanner> {
  late Timer _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsRemaining = _remaining());
    });
  }

  @override
  void didUpdateWidget(covariant _PendingApprovalBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approval.approvalId != widget.approval.approvalId) {
      _timer.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secondsRemaining = _remaining());
      });
      setState(() => _secondsRemaining = _remaining());
    }
  }

  int _remaining() {
    final expiry = widget.approval.expiresAt;
    return expiry.difference(DateTime.now()).inSeconds.clamp(0, 300);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolName = widget.approval.toolName.ifEmpty('tool');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          _PulseHalo(
            color: _accent,
            animate: true,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.security_outlined, size: 13, color: _accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: _textPrimary, fontSize: 13),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Waiting for approval: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: toolName,
                    style: TextStyle(color: _accent),
                  ),
                  TextSpan(
                    text: '  ${_secondsRemaining}s',
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final disabled = status?.status == 'disabled';
    final canDisconnect = configured && !connected && !disabled;
    final isDisconnecting = controller.isMessagingPlatformBusy(
      platform.id,
      'disconnect',
    );
    final isSigningIn =
        platform.connectMethod == MessagingConnectMethod.integration &&
        controller.isOfficialIntegrationBusy(
          '${platform.integrationProvider}:${platform.integrationApp}:connect',
        );
    final accent = platform.accent;
    final actionLabel = connected
        ? 'Connected'
        : isSigningIn
        ? 'Signing in...'
        : disabled
        ? 'Disabled'
        : configured
        ? 'Reconnect'
        : 'Connect';
    final accessLabel = accessCatalog.compactAccessLabel;
    // Self-chat mode answers only the account owner's own notes, so there is
    // nobody to allow and no other chat to review.
    final selfChatOnly =
        platform.id == 'whatsapp' && readWhatsAppSelfChatMode(controller);
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
                    : disabled
                    ? 'Disabled'
                    : configured
                    ? 'Ready'
                    : 'Setup',
                color: connected
                    ? _success
                    : disabled
                    ? _textMuted
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
              if (!selfChatOnly)
                _MessagingMiniPill(
                  icon: Icons.forum_outlined,
                  label: accessLabel,
                ),
              if (configured && !connected)
                const _MessagingMiniPill(
                  icon: Icons.tune_rounded,
                  label: 'Ready to connect',
                ),
              if (platform.id == 'whatsapp')
                _MessagingMiniPill(
                  icon: selfChatOnly
                      ? Icons.bookmark_border_rounded
                      : Icons.smartphone_rounded,
                  label: selfChatOnly ? 'Self-chat only' : 'Separate account',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: isDisconnecting ? null : onDisconnect,
                        icon: isDisconnecting
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.link_off_rounded, size: 18),
                        label: Text(
                          'Disconnect',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: disabled || isDisconnecting || isSigningIn
                            ? null
                            : onConnect,
                        icon: Icon(Icons.power_settings_new_rounded, size: 18),
                        label: Text(
                          actionLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
              ),
              if (canDisconnect) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Disconnect platform',
                  onPressed: isDisconnecting ? null : onDisconnect,
                  icon: isDisconnecting
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.link_off_rounded),
                ),
              ],
              if (platform.id == 'whatsapp') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Chat mode',
                  onPressed: onConnect,
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              if (!selfChatOnly) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Who can message',
                  onPressed: () => _editAccessPolicy(context, controller),
                  icon: Icon(Icons.forum_outlined),
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
      agentName: controller.activeAgentLabel,
      initialCatalog: catalog,
      onRefreshCatalog: () =>
          controller.loadMessagingAccessCatalog(platform.id, force: true),
      onSave: (policy) =>
          controller.saveMessagingAccessPolicy(platform.id, policy),
    );
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
  required String agentName,
  required MessagingAccessCatalog initialCatalog,
  required Future<MessagingAccessCatalog> Function() onRefreshCatalog,
  required Future<void> Function(MessagingAccessPolicy policy) onSave,
}) async {
  var catalog = initialCatalog;
  var policy = initialCatalog.policy;

  List<MessagingAccessRule> dedupeRules(List<MessagingAccessRule> rules) {
    final result = <MessagingAccessRule>[];
    for (final rule in rules) {
      if (rule.value.trim().isEmpty) continue;
      final index = result.indexWhere((item) => item.id == rule.id);
      if (index < 0) {
        result.add(rule);
        continue;
      }
      final current = result[index];
      if (looksLikeRawMessagingId(current.displayLabel) &&
          !looksLikeRawMessagingId(rule.displayLabel)) {
        result[index] = MessagingAccessRule(
          scope: current.scope,
          value: current.value,
          label: rule.label ?? rule.value,
          spaceScope: current.spaceScope ?? rule.spaceScope,
          spaceValue: current.spaceValue ?? rule.spaceValue,
          spaceLabel: (current.spaceLabel ?? '').trim().isNotEmpty
              ? current.spaceLabel
              : rule.spaceLabel,
        );
      }
    }
    return result;
  }

  List<MessagingAccessRule> sharedSpaces() {
    final spaces = <MessagingAccessRule>[
      ...policy.sharedSpaceRules,
      ...policy.sharedMemberRules
          .where(
            (rule) =>
                (rule.spaceScope ?? '').isNotEmpty &&
                (rule.spaceValue ?? '').isNotEmpty,
          )
          .map(
            (rule) => MessagingAccessRule(
              scope: rule.spaceScope!,
              value: rule.spaceValue!,
              label: rule.spaceLabel,
            ),
          ),
      ...policy.sharedParticipationRules.map(
        (rule) => MessagingAccessRule(
          scope: rule.scope,
          value: rule.value,
          label: rule.label,
        ),
      ),
      ...catalog.suggestedTargets
          .where((target) => target.bucket == 'sharedSpaceRules')
          .map((target) => target.asRule),
      ...catalog.discoveredTargets
          .where((target) => target.bucket == 'sharedSpaceRules')
          .map((target) => target.asRule),
    ];
    return dedupeRules(spaces).where((rule) => rule.isSharedSpace).toList();
  }

  bool allowsUntagged(MessagingAccessRule space) {
    for (final rule in policy.sharedParticipationRules) {
      if (rule.scope == space.scope && rule.value == space.value) {
        return rule.allowUntagged;
      }
    }
    return policy.defaultAllowUntaggedInShared;
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
            directPolicy: policy.directPolicy == 'disabled'
                ? 'allowlist'
                : policy.directPolicy,
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedActorRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedActorRules,
              selection.rule,
            ]),
          );
          break;
        case 'sharedMemberRules':
          policy = policy.copyWith(
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedMemberRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedMemberRules,
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
        case 'sharedMemberRules':
          policy = policy.copyWith(
            sharedMemberRules: policy.sharedMemberRules
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
          final participationSpaces = sharedSpaces();
          final previewCatalog = MessagingAccessCatalog(
            platform: catalog.platform,
            policy: policy,
            capabilities: capabilities,
            discoveredTargets: catalog.discoveredTargets,
            suggestedTargets: catalog.suggestedTargets,
            summary: catalog.summary,
          );

          return AlertDialog(
            backgroundColor: _bgCard,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: platform.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.forum_outlined, color: platform.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Who can message on ${platform.label}',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Choose who $agentName talks to, and when it joins group chats.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MessagingAccessSummaryCard(
                      accent: platform.accent,
                      headline: previewCatalog.accessHeadline(
                        agentName: agentName,
                      ),
                      hint: previewCatalog.accessHint(agentName: agentName),
                      details: previewCatalog.accessDetailChips,
                    ),
                    const SizedBox(height: 18),
                    if (capabilities.supportsDirectPolicy)
                      _AccessModeField(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Private chats',
                        description:
                            'Who can send $agentName a one-to-one message.',
                        value: policy.directPolicy,
                        shared: false,
                        agentName: agentName,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(directPolicy: value);
                        }),
                      ),
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 12),
                      _AccessModeField(
                        icon: Icons.groups_2_outlined,
                        label: 'Groups and channels',
                        description:
                            'Who can talk to $agentName in a group, channel, or room.',
                        value: policy.sharedPolicy,
                        shared: true,
                        modes: capabilities.sharedModes,
                        agentName: agentName,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(sharedPolicy: value);
                        }),
                      ),
                    ],
                    if (capabilities.supportsUntaggedGroupToggle) ...<Widget>[
                      const SizedBox(height: 16),
                      _GroupParticipationSection(
                        spaces: participationSpaces,
                        agentName: agentName,
                        approvedOnly: policy.sharedPolicy == 'allowlist',
                        supportsMentionGate: capabilities.supportsMentionGate,
                        defaultAllowUntagged:
                            policy.defaultAllowUntaggedInShared,
                        allowsUntagged: allowsUntagged,
                        onEdit: () async {
                          final selection = await _showSocialIntelligencePicker(
                            context,
                            spaces: participationSpaces,
                            agentName: agentName,
                            approvedOnly: policy.sharedPolicy == 'allowlist',
                            supportsMentionGate:
                                capabilities.supportsMentionGate,
                            defaultAllowUntagged:
                                policy.defaultAllowUntaggedInShared,
                            allowsUntagged: allowsUntagged,
                          );
                          if (selection == null) return;
                          setLocalState(() {
                            final selectedKeys = <String>{
                              for (final space in participationSpaces)
                                '${space.scope}:${space.value}',
                            };
                            policy = policy.copyWith(
                              defaultAllowUntaggedInShared:
                                  selection.defaultAllowUntagged,
                              sharedParticipationRules:
                                  <MessagingSharedParticipationRule>[
                                    ...policy.sharedParticipationRules.where(
                                      (rule) => !selectedKeys.contains(rule.id),
                                    ),
                                    ...selection.participationRules,
                                  ],
                            );
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Approved people and groups',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      policy.directPolicy == 'allowlist' ||
                              policy.sharedPolicy == 'allowlist'
                          ? 'Add the people and groups $agentName is allowed to talk to.'
                          : 'These lists are optional unless a section above is set to approved only.',
                      style: TextStyle(color: _textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
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
                          label: Text('Add people or groups'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final refreshed = await onRefreshCatalog();
                            if (!context.mounted) return;
                            setLocalState(() {
                              catalog = refreshed;
                            });
                          },
                          icon: Icon(Icons.travel_explore_rounded),
                          label: Text('Find recent chats'),
                        ),
                      ],
                    ),
                    if (capabilities.supportsDirectPolicy) ...<Widget>[
                      const SizedBox(height: 18),
                      _AccessRuleSection(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'People in private chats',
                        subtitle:
                            'These people can message $agentName one-to-one. This does not let them speak in groups.',
                        rules: policy.directRules,
                        emptyLabel: 'No one added yet.',
                        onRemove: (rule) =>
                            removeRule('directRules', rule, setLocalState),
                      ),
                    ],
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        icon: Icons.groups_2_outlined,
                        title: capabilities.requireSharedActor
                            ? 'Where $agentName listens'
                            : 'Whole groups',
                        subtitle: capabilities.requireSharedActor
                            ? '$agentName watches these places for mentions. Anyone can post here, so people still need their own approval below.'
                            : 'Everyone in these groups, channels, or rooms can talk to $agentName.',
                        rules: policy.sharedSpaceRules,
                        emptyLabel: 'No groups added yet.',
                        onRemove: (rule) =>
                            removeRule('sharedSpaceRules', rule, setLocalState),
                      ),
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        icon: Icons.person_outline_rounded,
                        title: 'These people, anywhere',
                        subtitle: capabilities.requireSharedActor
                            ? 'These people can ask $agentName wherever they tag it. Roles count only in the places listed above.'
                            : 'These people can message $agentName in private chats and in any group they share.',
                        rules: policy.sharedActorRules,
                        emptyLabel: 'No people added yet.',
                        onRemove: (rule) =>
                            removeRule('sharedActorRules', rule, setLocalState),
                      ),
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        icon: Icons.person_pin_circle_outlined,
                        title: 'These people, in one group',
                        subtitle:
                            'These people can only message $agentName in the group you picked.',
                        rules: policy.sharedMemberRules,
                        emptyLabel: 'No group-specific people added yet.',
                        onRemove: (rule) => removeRule(
                          'sharedMemberRules',
                          rule,
                          setLocalState,
                        ),
                        showSpace: true,
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
                child: Text('Save changes'),
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
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.agentName,
    this.shared = false,
    this.modes = const <String>['allowlist', 'open', 'disabled'],
  });

  final IconData icon;
  final String label;
  final String description;
  final String value;
  final ValueChanged<String> onChanged;
  final String agentName;
  final bool shared;

  /// The modes this platform offers; public platforms leave out 'open'.
  final List<String> modes;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(description, style: TextStyle(color: _textSecondary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (modes.contains('allowlist'))
                      ChoiceChip(
                        avatar: Icon(Icons.verified_user_outlined, size: 18),
                        label: Text('Approved only'),
                        selected: value == 'allowlist',
                        onSelected: (_) => onChanged('allowlist'),
                      ),
                    if (modes.contains('open'))
                      ChoiceChip(
                        avatar: Icon(Icons.public_rounded, size: 18),
                        label: Text('Anyone'),
                        selected: value == 'open',
                        onSelected: (_) => onChanged('open'),
                      ),
                    if (modes.contains('disabled'))
                      ChoiceChip(
                        avatar: Icon(Icons.block_rounded, size: 18),
                        label: Text('No one'),
                        selected: value == 'disabled',
                        onSelected: (_) => onChanged('disabled'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  messagingAccessModeHelp(
                    value,
                    shared: shared,
                    agentName: agentName,
                  ),
                  style: TextStyle(
                    color: _textSecondary,
                    height: 1.35,
                    fontSize: 13,
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

class _SocialIntelligenceSelection {
  const _SocialIntelligenceSelection({
    required this.defaultAllowUntagged,
    required this.participationRules,
  });

  final bool defaultAllowUntagged;
  final List<MessagingSharedParticipationRule> participationRules;
}

class _GroupParticipationSection extends StatelessWidget {
  const _GroupParticipationSection({
    required this.spaces,
    required this.agentName,
    required this.approvedOnly,
    required this.supportsMentionGate,
    required this.defaultAllowUntagged,
    required this.allowsUntagged,
    required this.onEdit,
  });

  final List<MessagingAccessRule> spaces;
  final String agentName;
  final bool approvedOnly;
  final bool supportsMentionGate;
  final bool defaultAllowUntagged;
  final bool Function(MessagingAccessRule) allowsUntagged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final enabledSpaces = spaces.where(allowsUntagged).toList(growable: false);
    final summaryText = spaces.isEmpty
        ? 'No groups found yet'
        : enabledSpaces.isEmpty
        ? defaultAllowUntagged
              ? 'On for new groups only'
              : 'Only when $agentName is tagged'
        : enabledSpaces.length == spaces.length
        ? 'On for all ${spaces.length} groups'
        : 'On for ${enabledSpaces.length} of ${spaces.length} groups';

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
          Row(
            children: <Widget>[
              Icon(Icons.chat_bubble_outline_rounded, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Join group conversations',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      approvedOnly
                          ? supportsMentionGate
                                ? '$agentName still only hears people and groups you already approved. This just lets $agentName join ordinary chat there, not only tags and replies.'
                                : '$agentName still only hears people and groups you already approved. This just chooses which of those groups it should join.'
                          : supportsMentionGate
                          ? 'If someone tags $agentName or replies, $agentName always answers. Turn this on if $agentName should also chime in on ordinary group chat.'
                          : 'Choose which groups $agentName should join even when nobody tags it. This platform may not tell tags apart from regular messages.',
                      style: TextStyle(color: _textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (spaces.isEmpty) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No groups found yet. After $agentName sees a group message, use Find recent chats and they will show up here.',
                style: TextStyle(color: _textMuted),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(Icons.tune_rounded),
              label: Text('Default for new groups'),
            ),
          ] else ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summaryText,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    defaultAllowUntagged
                        ? approvedOnly
                              ? 'New groups will let $agentName join ordinary chat with approved people, until you turn them off.'
                              : 'New groups will let $agentName join ordinary chat until you turn them off.'
                        : approvedOnly
                        ? 'New groups stay quiet unless an approved person tags $agentName, until you turn them on.'
                        : 'New groups stay quiet unless someone tags $agentName, until you turn them on.',
                    style: TextStyle(color: _textSecondary, height: 1.35),
                  ),
                  if (enabledSpaces.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ...enabledSpaces
                            .take(4)
                            .map(
                              (space) => Chip(
                                avatar: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: _accent,
                                ),
                                label: Text(space.displayLabel),
                              ),
                            ),
                        if (enabledSpaces.length > 4)
                          Chip(
                            label: Text('+${enabledSpaces.length - 4} more'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEdit,
              icon: Icon(Icons.tune_rounded),
              label: Text('Choose groups'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<_SocialIntelligenceSelection?> _showSocialIntelligencePicker(
  BuildContext context, {
  required List<MessagingAccessRule> spaces,
  required String agentName,
  required bool approvedOnly,
  required bool supportsMentionGate,
  required bool defaultAllowUntagged,
  required bool Function(MessagingAccessRule) allowsUntagged,
}) {
  return showDialog<_SocialIntelligenceSelection>(
    context: context,
    builder: (dialogContext) {
      return _SocialIntelligencePickerDialog(
        spaces: spaces,
        agentName: agentName,
        approvedOnly: approvedOnly,
        supportsMentionGate: supportsMentionGate,
        defaultAllowUntagged: defaultAllowUntagged,
        allowsUntagged: allowsUntagged,
      );
    },
  );
}

class _SocialIntelligencePickerDialog extends StatefulWidget {
  const _SocialIntelligencePickerDialog({
    required this.spaces,
    required this.agentName,
    required this.approvedOnly,
    required this.supportsMentionGate,
    required this.defaultAllowUntagged,
    required this.allowsUntagged,
  });

  final List<MessagingAccessRule> spaces;
  final String agentName;
  final bool approvedOnly;
  final bool supportsMentionGate;
  final bool defaultAllowUntagged;
  final bool Function(MessagingAccessRule) allowsUntagged;

  @override
  State<_SocialIntelligencePickerDialog> createState() =>
      _SocialIntelligencePickerDialogState();
}

class _SocialIntelligencePickerDialogState
    extends State<_SocialIntelligencePickerDialog> {
  static const String _filterAll = 'all';
  static const String _filterOn = 'on';
  static const String _filterOff = 'off';

  late final TextEditingController _searchController;
  late bool _defaultAllowUntagged;
  late final Set<String> _enabledIds;
  String _filter = _filterAll;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _defaultAllowUntagged = widget.defaultAllowUntagged;
    _enabledIds = <String>{
      for (final space in widget.spaces)
        if (widget.allowsUntagged(space)) space.id,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isEnabled(MessagingAccessRule space) => _enabledIds.contains(space.id);

  void _setEnabled(MessagingAccessRule space, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledIds.add(space.id);
      } else {
        _enabledIds.remove(space.id);
      }
    });
  }

  List<MessagingAccessRule> get _filteredSpaces {
    final query = _searchController.text.trim().toLowerCase();
    return widget.spaces
        .where((space) {
          final enabled = _isEnabled(space);
          if (_filter == _filterOn && !enabled) return false;
          if (_filter == _filterOff && enabled) return false;
          if (_filter != _filterAll &&
              _filter != _filterOn &&
              _filter != _filterOff &&
              space.scope != _filter) {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack =
              '${space.displayLabel} ${space.scopeLabel} ${space.scope} ${space.value}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Map<String, List<MessagingAccessRule>> get _groupedSpaces {
    final grouped = <String, List<MessagingAccessRule>>{};
    for (final space in _filteredSpaces) {
      grouped.putIfAbsent(space.scopeLabel, () => <MessagingAccessRule>[]);
      grouped[space.scopeLabel]!.add(space);
    }
    return grouped;
  }

  List<String> get _availableScopes {
    final seen = <String>{};
    final scopes = <String>[];
    for (final space in widget.spaces) {
      if (seen.add(space.scope)) {
        scopes.add(space.scope);
      }
    }
    return scopes;
  }

  _SocialIntelligenceSelection _selection() {
    return _SocialIntelligenceSelection(
      defaultAllowUntagged: _defaultAllowUntagged,
      participationRules: widget.spaces
          .map(
            (space) => MessagingSharedParticipationRule(
              scope: space.scope,
              value: space.value,
              label: space.label,
              allowUntagged: _isEnabled(space),
            ),
          )
          .toList(growable: false),
    );
  }

  IconData _scopeIcon(String scope) {
    switch (scope) {
      case 'group':
        return Icons.groups_2_outlined;
      case 'channel':
        return Icons.tag_rounded;
      case 'server':
        return Icons.dns_outlined;
      case 'room':
        return Icons.meeting_room_outlined;
      case 'chat':
        return Icons.forum_outlined;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedSpaces;
    final enabledCount = widget.spaces.where(_isEnabled).length;
    final query = _searchController.text.trim();

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          minWidth: 320,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: _bgCard,
            borderRadius: BorderRadius.circular(20),
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Join group conversations',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  enabledCount == 0
                                      ? widget.approvedOnly
                                            ? 'Only when an approved person tags ${widget.agentName}, unless you turn a group on'
                                            : 'Only when ${widget.agentName} is tagged, unless you turn a group on'
                                      : widget.approvedOnly
                                      ? '$enabledCount of ${widget.spaces.length} groups join ordinary chat with approved people'
                                      : '$enabledCount of ${widget.spaces.length} groups join ordinary chat',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: _textSecondary,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        widget.approvedOnly
                            ? widget.supportsMentionGate
                                  ? 'This does not approve new people. Tags and replies from approved people always get a response. Turn a group on if ${widget.agentName} should also join ordinary chat there.'
                                  : 'This does not approve new people. Turn a group on if ${widget.agentName} should join ordinary chat with people you already approved.'
                            : widget.supportsMentionGate
                            ? 'Tags and replies always get a response. Turn a group on if ${widget.agentName} should also join ordinary chat there.'
                            : 'Turn a group on if ${widget.agentName} should also read messages that do not tag it.',
                        style: TextStyle(
                          color: _textSecondary,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: _textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search groups',
                          hintStyle: TextStyle(color: _textMuted, fontSize: 14),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: _textMuted,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                  }),
                                  icon: Icon(
                                    Icons.cancel_rounded,
                                    size: 16,
                                    color: _textMuted,
                                  ),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: _bgSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ChoiceChip(
                            label: Text('All'),
                            selected: _filter == _filterAll,
                            onSelected: (_) =>
                                setState(() => _filter = _filterAll),
                          ),
                          ChoiceChip(
                            label: Text('On'),
                            selected: _filter == _filterOn,
                            onSelected: (_) =>
                                setState(() => _filter = _filterOn),
                          ),
                          ChoiceChip(
                            label: Text('Off'),
                            selected: _filter == _filterOff,
                            onSelected: (_) =>
                                setState(() => _filter = _filterOff),
                          ),
                          ..._availableScopes.map(
                            (scope) => ChoiceChip(
                              avatar: Icon(_scopeIcon(scope), size: 16),
                              label: Text(
                                MessagingAccessRule(
                                  scope: scope,
                                  value: scope,
                                ).scopeLabel,
                              ),
                              selected: _filter == scope,
                              onSelected: (_) =>
                                  setState(() => _filter = scope),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          title: Text(
                            'On by default for new groups',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Groups ${widget.agentName} has not seen yet will follow this.',
                            style: TextStyle(color: _textSecondary),
                          ),
                          value: _defaultAllowUntagged,
                          onChanged: (value) => setState(() {
                            _defaultAllowUntagged = value;
                          }),
                        ),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: _border),
                    Flexible(
                      child: widget.spaces.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'No groups found yet. After ${widget.agentName} sees a group message, use Find recent chats.',
                                style: TextStyle(color: _textMuted),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _filteredSpaces.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 36,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    query.isEmpty
                                        ? 'No groups in this category'
                                        : 'No results for "$query"',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                              shrinkWrap: true,
                              children: grouped.entries
                                  .expand((entry) {
                                    return <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          8,
                                          8,
                                          4,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _textSecondary,
                                            fontSize: 12,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      ...entry.value.map((space) {
                                        final enabled = _isEnabled(space);
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _bgSecondary,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: SwitchListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 2,
                                                ),
                                            secondary: Icon(
                                              enabled
                                                  ? Icons
                                                        .chat_bubble_outline_rounded
                                                  : _scopeIcon(space.scope),
                                              color: enabled
                                                  ? _accent
                                                  : _textMuted,
                                            ),
                                            title: Text(
                                              space.displayLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              enabled
                                                  ? widget.approvedOnly
                                                        ? '${widget.agentName} joins ordinary chat with approved people'
                                                        : '${widget.agentName} can join ordinary chat'
                                                  : widget.approvedOnly
                                                  ? '${widget.agentName} only replies when an approved person tags it'
                                                  : '${widget.agentName} only replies when tagged',
                                              style: TextStyle(
                                                color: _textSecondary,
                                              ),
                                            ),
                                            value: enabled,
                                            onChanged: (value) =>
                                                _setEnabled(space, value),
                                          ),
                                        );
                                      }),
                                    ];
                                  })
                                  .toList(growable: false),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Row(
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selection()),
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    this.icon,
    this.showSpace = false,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final List<MessagingAccessRule> rules;
  final String emptyLabel;
  final ValueChanged<MessagingAccessRule> onRemove;
  final bool showSpace;

  IconData _scopeIcon(String scope) {
    switch (scope) {
      case 'group':
        return Icons.groups_2_outlined;
      case 'channel':
        return Icons.tag_rounded;
      case 'server':
        return Icons.dns_outlined;
      case 'room':
        return Icons.meeting_room_outlined;
      case 'phone_number':
        return Icons.phone_outlined;
      case 'role':
        return Icons.badge_outlined;
      case 'user':
      case 'dm':
        return Icons.person_outline_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

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
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: _accent, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: _textSecondary, height: 1.35)),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            Text(emptyLabel, style: TextStyle(color: _textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules
                  .map((rule) {
                    final spaceSuffix =
                        showSpace && rule.spaceDisplayLabel.isNotEmpty
                        ? ' in ${rule.spaceDisplayLabel}'
                        : '';
                    return Chip(
                      avatar: Icon(_scopeIcon(rule.scope), size: 16),
                      label: Text('${rule.displayLabel}$spaceSuffix'),
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
  // Use BottomSheet for contextual actions, AlertDialog for confirmations.
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
  late final TextEditingController _valueController;
  late final TextEditingController _spaceValueController;
  late String _selectedBucket;
  late String _selectedScope;
  late String _selectedSpaceScope;
  late bool _showManualEntry;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _valueController = TextEditingController();
    _spaceValueController = TextEditingController();
    _showManualEntry =
        widget.catalog.discoveredTargets.isEmpty &&
        widget.catalog.suggestedTargets.isEmpty;
    _selectedBucket =
        widget.catalog.capabilities.sharedActorRuleScopes.isNotEmpty
        ? 'sharedActorRules'
        : _directOnlyScopes().isNotEmpty
        ? 'directRules'
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? 'sharedSpaceRules'
              : 'sharedActorRules');
    _selectedScope =
        widget.catalog.capabilities.sharedActorRuleScopes.isNotEmpty
        ? widget.catalog.capabilities.sharedActorRuleScopes.first
        : _directOnlyScopes().isNotEmpty
        ? _directOnlyScopes().first
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? widget.catalog.capabilities.sharedSpaceRuleScopes.first
              : (widget.catalog.capabilities.sharedActorRuleScopes.isNotEmpty
                    ? widget.catalog.capabilities.sharedActorRuleScopes.first
                    : 'chat'));
    _selectedSpaceScope =
        widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
        ? widget.catalog.capabilities.sharedSpaceRuleScopes.first
        : 'chat';
  }

  @override
  void dispose() {
    _queryController.dispose();
    _valueController.dispose();
    _spaceValueController.dispose();
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
        return _directOnlyScopes();
      case 'sharedActorRules':
      case 'sharedMemberRules':
        return widget.catalog.capabilities.sharedActorRuleScopes;
      default:
        return widget.catalog.capabilities.sharedSpaceRuleScopes;
    }
  }

  List<String> _directOnlyScopes() {
    final sharedActorScopes = widget.catalog.capabilities.sharedActorRuleScopes
        .toSet();
    return widget.catalog.capabilities.directRuleScopes
        .where((scope) => !sharedActorScopes.contains(scope))
        .toList(growable: false);
  }

  void _syncSelectedScope() {
    final availableScopes = _scopesForBucket();
    if (availableScopes.isEmpty || availableScopes.contains(_selectedScope)) {
      return;
    }
    _selectedScope = availableScopes.first;
  }

  void _submitManualRule(BuildContext context) {
    final value = _valueController.text.trim();
    if (value.isEmpty) return;
    final isMemberRule = _selectedBucket == 'sharedMemberRules';
    final spaceValue = _spaceValueController.text.trim();
    if (isMemberRule && spaceValue.isEmpty) return;
    Navigator.of(context).pop(
      _MessagingRuleSelection(
        bucket: _selectedBucket,
        rule: MessagingAccessRule(
          scope: _selectedScope,
          value: value,
          spaceScope: isMemberRule ? _selectedSpaceScope : null,
          spaceValue: isMemberRule ? spaceValue : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableScopes = _scopesForBucket();
    final query = _queryController.text.trim().toLowerCase();
    final allTargets = <MessagingAccessTarget>[
      ...widget.catalog.suggestedTargets,
      ...widget.catalog.discoveredTargets,
    ];
    bool matchesQuery(MessagingAccessTarget target) {
      if (query.isEmpty) return true;
      final haystack =
          '${target.label} ${target.subtitle} ${target.scope} ${target.value}'
              .toLowerCase();
      return haystack.contains(query);
    }

    final targets = allTargets
        .where((target) {
          if (target.bucket != _selectedBucket) return false;
          return matchesQuery(target);
        })
        .toList(growable: false);
    final memberActorTargets = allTargets
        .where(
          (target) =>
              target.bucket == 'sharedActorRules' && matchesQuery(target),
        )
        .toList(growable: false);
    final memberSpaceTargets = allTargets
        .where(
          (target) =>
              target.bucket == 'sharedSpaceRules' && matchesQuery(target),
        )
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
              'Add someone or a group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick from recent ${widget.platform.label} chats, or add a person or group yourself.',
              style: TextStyle(color: _textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),
            Text(
              'What are you adding?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (_directOnlyScopes().isNotEmpty)
                  ChoiceChip(
                    label: Text('Private chat'),
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
                    label: Text('Whole group'),
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
                    label: Text('This person, anywhere'),
                    selected: _selectedBucket == 'sharedActorRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedActorRules';
                      _syncSelectedScope();
                    }),
                  ),
                if (widget
                        .catalog
                        .capabilities
                        .sharedActorRuleScopes
                        .isNotEmpty &&
                    widget
                        .catalog
                        .capabilities
                        .sharedSpaceRuleScopes
                        .isNotEmpty)
                  ChoiceChip(
                    label: Text('This person, in one group'),
                    selected: _selectedBucket == 'sharedMemberRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedMemberRules';
                      _syncSelectedScope();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search recent people and groups',
              ),
            ),
            const SizedBox(height: 16),
            if (targets.isNotEmpty) ...<Widget>[
              Text(
                'Recent chats',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...targets.take(10).map((target) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    target.bucket == 'sharedSpaceRules'
                        ? Icons.groups_2_outlined
                        : Icons.person_outline_rounded,
                    color: _accent,
                  ),
                  title: Text(target.label),
                  subtitle: Text(
                    target.subtitle.ifEmpty(
                      messagingScopePickerLabel(target.scope),
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
            if (_selectedBucket == 'sharedMemberRules' &&
                (memberActorTargets.isNotEmpty ||
                    memberSpaceTargets.isNotEmpty)) ...<Widget>[
              if (memberActorTargets.isNotEmpty) ...<Widget>[
                Text(
                  'Choose a person',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memberActorTargets
                      .take(10)
                      .map((target) {
                        return ActionChip(
                          label: Text(target.label),
                          onPressed: () => setState(() {
                            _selectedScope = target.scope;
                            _valueController.text = target.value;
                            _showManualEntry = true;
                          }),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
              ],
              if (memberSpaceTargets.isNotEmpty) ...<Widget>[
                Text(
                  'Choose their group',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memberSpaceTargets
                      .take(10)
                      .map((target) {
                        return ActionChip(
                          label: Text(target.label),
                          onPressed: () => setState(() {
                            _selectedSpaceScope = target.scope;
                            _spaceValueController.text = target.value;
                            _showManualEntry = true;
                          }),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
              ],
              const Divider(height: 10),
            ],
            if (!_showManualEntry)
              TextButton.icon(
                onPressed: () => setState(() => _showManualEntry = true),
                icon: Icon(Icons.edit_outlined),
                label: Text('Add by name or ID instead'),
              )
            else ...<Widget>[
              Text(
                'Add by name or ID',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (availableScopes.isNotEmpty)
                InputDecorator(
                  decoration: InputDecoration(labelText: 'Type'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedScope,
                      isExpanded: true,
                      items: availableScopes
                          .map(
                            (scope) => DropdownMenuItem<String>(
                              value: scope,
                              child: Text(messagingScopePickerLabel(scope)),
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
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: _selectedBucket == 'sharedMemberRules'
                      ? 'Person'
                      : _selectedBucket == 'sharedSpaceRules'
                      ? 'Group or channel'
                      : 'Person or chat',
                  helperText: widget.catalog.capabilities.manualEntryHint
                      .ifEmpty('Use a name, phone number, or chat ID.'),
                  helperMaxLines: 3,
                ),
                onSubmitted: _selectedBucket == 'sharedMemberRules'
                    ? null
                    : (_) => _submitManualRule(context),
              ),
              if (_selectedBucket == 'sharedMemberRules') ...<Widget>[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(labelText: 'Group type'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSpaceScope,
                      isExpanded: true,
                      items: widget.catalog.capabilities.sharedSpaceRuleScopes
                          .map(
                            (scope) => DropdownMenuItem<String>(
                              value: scope,
                              child: Text(messagingScopePickerLabel(scope)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedSpaceScope = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _spaceValueController,
                  decoration: InputDecoration(
                    labelText: 'Group, channel, or room',
                  ),
                  onSubmitted: (_) => _submitManualRule(context),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _submitManualRule(context),
                  icon: Icon(Icons.add_rounded),
                  label: Text('Add'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessagingWebhookCard extends StatelessWidget {
  const _MessagingWebhookCard({
    required this.url,
    required this.platformLabel,
    required this.agentName,
  });

  final String url;
  final String platformLabel;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Incoming messages',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'If $platformLabel asks for a webhook URL, paste this so messages can reach $agentName.',
            style: TextStyle(color: _textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  url,
                  style: TextStyle(fontSize: 12, color: _textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Copy webhook URL',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Webhook URL copied')),
                  );
                },
                icon: Icon(Icons.copy_outlined, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
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

// ──────────────────────────────────────────────────────────────────────────────

Future<void> openMessagingConfig(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  if (platform.connectMethod == MessagingConnectMethod.integration) {
    return _connectIntegrationMessagingPlatform(context, controller, platform);
  }
  switch (platform.id) {
    case 'whatsapp':
      return _openWhatsAppModeDialog(context, controller, platform);
    default:
      return _openGenericMessagingConfigHelper(context, controller, platform);
  }
}

Future<void> _connectIntegrationMessagingPlatform(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await controller.connectIntegrationMessagingPlatform(platform);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          '${platform.label} connected. Choose repositories and people under Who can message.',
        ),
      ),
    );
  } catch (error) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Failed to connect ${platform.label}: ${controller.friendlyErrorMessage(error)}',
        ),
      ),
    );
  }
}

bool readWhatsAppSelfChatMode(NeoAgentController controller) {
  final saved = _jsonMap(_decodeMaybeJson(controller.settings['whatsapp_config']));
  return saved['selfChatMode'] == true ||
      saved['selfChatMode']?.toString() == 'true';
}

Future<void> _openWhatsAppModeDialog(
  BuildContext context,
  NeoAgentController controller,
  MessagingPlatformDescriptor platform,
) async {
  var selfChatMode = readWhatsAppSelfChatMode(controller);

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          Widget modeTile({
            required bool value,
            required IconData icon,
            required String title,
            required String description,
          }) {
            final selected = selfChatMode == value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setLocalState(() => selfChatMode = value),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selected
                        ? platform.accent.withValues(alpha: 0.08)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected ? platform.accent : _borderLight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        icon,
                        size: 20,
                        color: selected ? platform.accent : _textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: _textSecondary,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: selected ? platform.accent : _textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: _bgCard,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            title: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: platform.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(platform.icon, color: platform.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Connect WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Pick how ${controller.activeAgentLabel} uses this account.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    modeTile(
                      value: false,
                      icon: Icons.smartphone_rounded,
                      title: 'Separate account',
                      description:
                          'Link a phone number that belongs to the agent. '
                          'Anyone you allow can chat with it, in direct chats and groups.',
                    ),
                    modeTile(
                      value: true,
                      icon: Icons.bookmark_border_rounded,
                      title: 'Personal self-chat',
                      description:
                          'Link your own number and talk to the agent in your '
                          '"Message yourself" chat. Every other chat and group on '
                          'this account is ignored.',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selfChatMode
                          ? 'Notes you write to yourself start a run, and replies land in the same chat. The allowlist does not apply here.'
                          : 'Choose who may message the agent with "Who can message" on the WhatsApp card.',
                      style: TextStyle(color: _textSecondary, height: 1.4),
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
                  final config = <String, dynamic>{'selfChatMode': selfChatMode};
                  final connected = await _connectMessagingPlatformHelper(
                    context,
                    controller,
                    platform: platform.id,
                    platformLabel: platform.label,
                    config: config,
                    configSnapshot: <String, dynamic>{
                      platform.settingsKey: jsonEncode(config),
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
}

Future<bool> _connectMessagingPlatformHelper(
  BuildContext context,
  NeoAgentController controller, {
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

Future<void> _openGenericMessagingConfigHelper(
  BuildContext context,
  NeoAgentController controller,
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
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              title: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: platform.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(platform.icon, color: platform.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Connect ${platform.label}',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          platform.subtitle,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        platform.configFields.isEmpty
                            ? 'Nothing extra is needed. Connect to start using ${platform.label}.'
                            : 'Enter the details ${platform.label} gave you so ${controller.activeAgentLabel} can send and receive messages.',
                        style: TextStyle(color: _textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (platform.configFields.isEmpty)
                        const SizedBox.shrink()
                      else
                        ...platform.configFields.map((field) {
                          if (field.kind == MessagingConfigFieldKind.boolean) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(field.label),
                                subtitle: field.hint == null
                                    ? null
                                    : Text(
                                        field.hint!,
                                        style: TextStyle(color: _textSecondary),
                                      ),
                                value: boolValues[field.key] ?? false,
                                onChanged: (value) {
                                  setLocalState(() {
                                    boolValues[field.key] = value;
                                  });
                                },
                              ),
                            );
                          }
                          final fieldController = textControllers[field.key]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: fieldController,
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
                                helperText: field.hint,
                                helperMaxLines: 3,
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      if (platform.id == 'meshtastic')
                        Text(
                          '${controller.activeAgentLabel} talks to the device on your local network (port 4403 by default). Chat stays on the channel you pick above.',
                          style: TextStyle(color: _textSecondary, height: 1.4),
                        )
                      else
                        _MessagingWebhookCard(
                          url:
                              '${controller.backendUrl}/api/messaging/webhook/${platform.id}',
                          platformLabel: platform.label,
                          agentName: controller.activeAgentLabel,
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
                    final connected = await _connectMessagingPlatformHelper(
                      context,
                      controller,
                      platform: platform.id,
                      platformLabel: platform.label,
                      config: config,
                      configSnapshot: snapshot,
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
    for (final controller in textControllers.values) {
      controller.dispose();
    }
  }
}
