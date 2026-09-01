part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cowork — desktop shell
//
// Layout: [sessions rail] [conversation] [workbench]. The rail and workbench
// collapse into overlays on narrower windows. The conversation, composer and
// workbench live in their own part files; this file owns layout, keyboard
// shortcuts, composer actions (send / attach / dictate) and the small shared
// atoms every Cowork surface uses.
// ─────────────────────────────────────────────────────────────────────────────

const double _coworkCompactWidth = 760;
const double _coworkWideWidth = 1180;
const double _coworkRailWidth = 264;

enum _CoworkWorkbenchTab { computer, files, changes }

/// A request to open a workspace file in the workbench. The nonce makes
/// repeated requests for the same path distinguishable.
class _CoworkFileRequest {
  const _CoworkFileRequest(this.path, this.nonce);

  final String path;
  final int nonce;
}

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
            leading: const _LogoBadge(size: 14),
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
  final FocusNode _shortcutFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  List<SharedChatAttachment> _attachments = const <SharedChatAttachment>[];
  LiveVoiceCapture? _dictationCapture;
  final List<Uint8List> _dictationChunks = <Uint8List>[];
  bool _isDictating = false;
  bool _isTranscribing = false;
  bool _showSessions = false;
  bool _workbenchOpen = true;
  _CoworkWorkbenchTab _workbenchTab = _CoworkWorkbenchTab.computer;
  _CoworkFileRequest? _fileRequest;
  int _fileRequestNonce = 0;

  NeoAgentController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(controller.refreshCowork());
      unawaited(controller.refreshAiCatalog());
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _shortcutFocus.dispose();
    _scroll.dispose();
    unawaited(_dictationCapture?.dispose());
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final content = _composer.text;
    if (content.trim().isEmpty && _attachments.isEmpty) return;
    final outgoingAttachments = _attachments;
    _composer.clear();
    setState(() => _attachments = const <SharedChatAttachment>[]);
    await controller.sendCoworkMessage(
      content,
      sharedAttachments: outgoingAttachments,
    );
    if (!mounted) return;
    _composerFocus.requestFocus();
    _scrollToEnd();
  }

  void _useStarter(String prompt) {
    _composer.text = prompt;
    _composer.selection = TextSelection.collapsed(offset: prompt.length);
    _composerFocus.requestFocus();
  }

  /// Appends an `@path` reference so the agent knows exactly which file the
  /// user means. Paths with spaces are quoted.
  void _insertReference(String path) {
    final reference = path.contains(' ') ? '@"$path"' : '@$path';
    final text = _composer.text;
    final separator = text.isEmpty || text.endsWith(' ') || text.endsWith('\n')
        ? ''
        : ' ';
    _composer.text = '$text$separator$reference ';
    _composer.selection = TextSelection.collapsed(
      offset: _composer.text.length,
    );
    _composerFocus.requestFocus();
  }

  void _openFile(String path) {
    setState(() {
      _workbenchOpen = true;
      _workbenchTab = _CoworkWorkbenchTab.files;
      _fileRequest = _CoworkFileRequest(path, ++_fileRequestNonce);
    });
  }

  Future<void> _newSession() =>
      controller.createCoworkChat(template: controller.selectedCoworkChat);

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
        final transcript = await controller.transcribeDictationAudio(
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

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    void stopRun() {
      if (controller.selectedCoworkThread.hasLiveRun) {
        unawaited(controller.stopCoworkRun());
      }
    }

    void toggleWorkbench() => setState(() => _workbenchOpen = !_workbenchOpen);
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newSession,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _newSession,
      const SingleActivator(LogicalKeyboardKey.period, meta: true): stopRun,
      const SingleActivator(LogicalKeyboardKey.period, control: true): stopRun,
      const SingleActivator(LogicalKeyboardKey.keyJ, meta: true):
          toggleWorkbench,
      const SingleActivator(LogicalKeyboardKey.keyJ, control: true):
          toggleWorkbench,
    };
  }

  @override
  Widget build(BuildContext context) {
    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CallbackShortcuts(
            bindings: _shortcuts(),
            child: Focus(
              focusNode: _shortcutFocus,
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < _coworkCompactWidth;
                  final wide = constraints.maxWidth >= _coworkWideWidth;
                  final railInline = !compact;
                  final workbenchInline = wide && _workbenchOpen;
                  final workbenchOverlay = !wide && _workbenchOpen;
                  final workbenchWidth = wide
                      ? (constraints.maxWidth * 0.34).clamp(380.0, 560.0)
                      : math.min(560.0, constraints.maxWidth * 0.92);
                  final gutter = compact ? 10.0 : 14.0;
                  return Column(
                    children: <Widget>[
                      _CoworkTopBar(
                        controller: controller,
                        compact: compact,
                        workbenchOpen: _workbenchOpen,
                        onToggleSessions: compact
                            ? () =>
                                  setState(() => _showSessions = !_showSessions)
                            : null,
                        onToggleWorkbench: () =>
                            setState(() => _workbenchOpen = !_workbenchOpen),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                          child: Stack(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  if (railInline) ...<Widget>[
                                    SizedBox(
                                      width: _coworkRailWidth,
                                      child: _CoworkSessionRail(
                                        controller: controller,
                                        onNew: _newSession,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: _CoworkConversation(
                                      controller: controller,
                                      scrollController: _scroll,
                                      compact: compact,
                                      onOpenFile: _openFile,
                                      onUseStarter: _useStarter,
                                      composer: _CoworkComposer(
                                        controller: controller,
                                        textController: _composer,
                                        focusNode: _composerFocus,
                                        attachments: _attachments,
                                        onRemoveAttachment: (attachment) =>
                                            setState(() {
                                              _attachments = _attachments
                                                  .where(
                                                    (item) =>
                                                        item != attachment,
                                                  )
                                                  .toList(growable: false);
                                            }),
                                        onAttach: _attachFiles,
                                        onDictate: _toggleDictation,
                                        onSend: _send,
                                        isDictating: _isDictating,
                                        isTranscribing: _isTranscribing,
                                        compact: compact,
                                      ),
                                    ),
                                  ),
                                  if (workbenchInline) ...<Widget>[
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: workbenchWidth,
                                      child: _CoworkWorkbench(
                                        controller: controller,
                                        tab: _workbenchTab,
                                        onTabChanged: (tab) =>
                                            setState(() => _workbenchTab = tab),
                                        fileRequest: _fileRequest,
                                        onInsertReference: _insertReference,
                                        onOpenFile: _openFile,
                                        onClose: () => setState(
                                          () => _workbenchOpen = false,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (compact && _showSessions)
                                _CoworkScrimPanel(
                                  alignment: Alignment.centerLeft,
                                  width: math.min(
                                    320,
                                    constraints.maxWidth * 0.86,
                                  ),
                                  onDismiss: () =>
                                      setState(() => _showSessions = false),
                                  child: _CoworkSessionRail(
                                    controller: controller,
                                    onNew: _newSession,
                                    onSelect: () =>
                                        setState(() => _showSessions = false),
                                    onClose: () =>
                                        setState(() => _showSessions = false),
                                  ),
                                ),
                              if (workbenchOverlay)
                                _CoworkScrimPanel(
                                  alignment: Alignment.centerRight,
                                  width: workbenchWidth,
                                  onDismiss: () =>
                                      setState(() => _workbenchOpen = false),
                                  child: _CoworkWorkbench(
                                    controller: controller,
                                    tab: _workbenchTab,
                                    onTabChanged: (tab) =>
                                        setState(() => _workbenchTab = tab),
                                    fileRequest: _fileRequest,
                                    onInsertReference: (path) {
                                      _insertReference(path);
                                      setState(() => _workbenchOpen = false);
                                    },
                                    onOpenFile: _openFile,
                                    onClose: () =>
                                        setState(() => _workbenchOpen = false),
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
        ),
      ),
    );
  }
}

class _CoworkTopBar extends StatelessWidget {
  const _CoworkTopBar({
    required this.controller,
    required this.compact,
    required this.workbenchOpen,
    required this.onToggleWorkbench,
    this.onToggleSessions,
  });

  final NeoAgentController controller;
  final bool compact;
  final bool workbenchOpen;
  final VoidCallback onToggleWorkbench;
  final VoidCallback? onToggleSessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 10, compact ? 12 : 18, 10),
      child: Row(
        children: <Widget>[
          if (onToggleSessions != null) ...<Widget>[
            _CoworkIconChip(
              tooltip: 'Sessions',
              icon: Icons.view_sidebar_outlined,
              onPressed: onToggleSessions!,
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
                Text('Cowork', style: _sectionEyebrowStyle()),
              ],
            ),
          ),
          if (!controller.socketConnected) ...<Widget>[
            const _CoworkLiveDot(connected: false),
            const SizedBox(width: 10),
          ],
          _CoworkIconChip(
            tooltip: workbenchOpen ? 'Hide workbench (⌘J)' : 'Show workbench (⌘J)',
            icon: workbenchOpen
                ? Icons.web_asset_rounded
                : Icons.web_asset_off_outlined,
            selected: workbenchOpen,
            onPressed: onToggleWorkbench,
          ),
          const SizedBox(width: 8),
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
            child: Padding(padding: const EdgeInsets.all(4), child: child),
          ),
        ),
      ],
    );
  }
}

// ─── Shared atoms ────────────────────────────────────────────────────────────

class _CoworkLiveDot extends StatelessWidget {
  const _CoworkLiveDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? _success : _danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Live' : 'Offline',
            style: GoogleFonts.geistMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
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
    this.size = 38,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
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
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.47,
              color: !enabled
                  ? _textMuted
                  : selected
                  ? _accent
                  : _textSecondary,
            ),
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
    this.dense = false,
  });

  final bool selected;
  final IconData? icon;
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final mark =
        leading ??
        (icon == null
            ? null
            : Icon(
                icon,
                size: dense ? 14 : 15,
                color: selected ? _bgPrimary : _textSecondary,
              ));
    return Material(
      color: selected ? _accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 6 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (mark != null) ...<Widget>[mark, const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? 12.5 : 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? _bgPrimary : _textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined pill that opens a menu; used for agent, device and folder pickers.
class _CoworkContextPill extends StatelessWidget {
  const _CoworkContextPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
    this.maxWidth = 180,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final color = accent ? _accentHover : _textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent
                ? _accentMuted.withValues(alpha: 0.7)
                : _bgSecondary.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: accent ? _accent.withValues(alpha: 0.35) : _borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: accent ? _accentHover : _textPrimary,
                  ),
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 15, color: _textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _coworkStatusColor(String? status) {
  switch (status ?? '') {
    case 'failed':
      return _danger;
    case 'paused' || 'waiting_input' || 'pausing':
      return _warning;
    case 'pending' || 'running' || 'resuming':
      return _success;
    default:
      return _textMuted;
  }
}

class _CoworkStatusDot extends StatelessWidget {
  const _CoworkStatusDot({this.status, this.live = false});

  final String? status;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = _coworkStatusColor(status);
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!live) return dot;
    return _PulseHalo(color: color, animate: true, child: dot);
  }
}

class _CoworkEmpty extends StatelessWidget {
  const _CoworkEmpty({
    required this.title,
    required this.message,
    this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon == null)
              const _LogoBadge(size: 44)
            else
              Icon(icon, size: 36, color: _textMuted),
            const SizedBox(height: 16),
            Text(title, style: _displayTitleStyle(20)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

String _coworkRelativeTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inSeconds < 45) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24 && now.day == time.day) {
    return '${difference.inHours}h ago';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day) {
    return 'Yesterday';
  }
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final date = '${months[time.month - 1]} ${time.day}';
  return time.year == now.year ? date : '$date ${time.year}';
}

String _coworkFormatTokens(int tokens) {
  if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
  return '$tokens';
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
