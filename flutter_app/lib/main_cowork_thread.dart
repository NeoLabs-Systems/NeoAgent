part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cowork — conversation column
//
// Header (title, context pills, run status), transcript (messages with the
// tool activity of each run inlined between the request and the reply),
// structured-input cards, and the composer slot.
// ─────────────────────────────────────────────────────────────────────────────

class _CoworkConversation extends StatelessWidget {
  const _CoworkConversation({
    required this.controller,
    required this.scrollController,
    required this.compact,
    required this.onOpenFile,
    required this.onUseStarter,
    required this.composer,
  });

  final NeoAgentController controller;
  final ScrollController scrollController;
  final bool compact;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<String> onUseStarter;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final chat = controller.selectedCoworkChat;
    final thread = controller.selectedCoworkThread;
    if (chat == null) {
      return _GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: _CoworkEmpty(
          title: 'Work on a project with NeoAgent',
          message:
              'Sessions are pinned to a folder and a computer. Start one to plan, build, test and ship from here.',
          action: FilledButton.icon(
            onPressed: () => unawaited(controller.createCoworkChat()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New session'),
          ),
        ),
      );
    }
    final showStarters =
        !thread.loading &&
        thread.messages.isEmpty &&
        thread.streamingContent.isEmpty &&
        !thread.hasLiveRun;
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgCard.withValues(alpha: 0.62),
      child: Column(
        children: <Widget>[
          _CoworkThreadHeader(
            controller: controller,
            chat: chat,
            thread: thread,
            compact: compact,
          ),
          Expanded(
            child: thread.loading
                ? const Center(child: CircularProgressIndicator())
                : showStarters
                ? _CoworkStarters(chat: chat, onPick: onUseStarter)
                : _CoworkTranscript(
                    controller: controller,
                    chat: chat,
                    thread: thread,
                    scrollController: scrollController,
                    compact: compact,
                    onOpenFile: onOpenFile,
                  ),
          ),
          composer,
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _CoworkThreadHeader extends StatelessWidget {
  const _CoworkThreadHeader({
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
    final agentLabel =
        agents
            .where((agent) => agent.id == chat.agentId)
            .map((agent) => agent.displayName)
            .firstOrNull ??
        chat.agentName;
    final latest = chat.latestRun;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 12, compact ? 10 : 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _renameCoworkChat(context, controller, chat),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
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
                ),
              ),
              const SizedBox(width: 8),
              _CoworkRunStatus(thread: thread, latest: latest),
              if (thread.hasLiveRun) ...<Widget>[
                const SizedBox(width: 6),
                _CoworkIconChip(
                  size: 34,
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
                  size: 34,
                  tooltip: 'Stop (⌘.)',
                  icon: Icons.stop_rounded,
                  onPressed: controller.stopCoworkRun,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PopupMenuButton<String>(
                tooltip: 'Agent profile',
                onSelected: (value) => controller.updateCoworkChat(
                  chat.id,
                  <String, dynamic>{'agentId': value},
                ),
                itemBuilder: (_) => agents
                    .map(
                      (agent) => PopupMenuItem<String>(
                        value: agent.id,
                        child: Text(agent.displayName),
                      ),
                    )
                    .toList(growable: false),
                child: _CoworkContextPill(
                  icon: Icons.person_outline_rounded,
                  label: agentLabel,
                ),
              ),
              _CoworkDeviceMenu(controller: controller, chat: chat),
              if (chat.isLocal)
                _CoworkWorkspaceMenu(controller: controller, chat: chat),
              if (latest != null && latest.totalTokens > 0)
                Tooltip(
                  message: latest.model == null
                      ? 'Tokens used by the latest run'
                      : 'Latest run · ${latest.model}',
                  child: _CoworkContextPill(
                    icon: Icons.data_usage_rounded,
                    label: '${_coworkFormatTokens(latest.totalTokens)} tokens',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live phase + elapsed clock while a run is active; last outcome otherwise.
class _CoworkRunStatus extends StatelessWidget {
  const _CoworkRunStatus({required this.thread, this.latest});

  final CoworkThreadState thread;
  final CoworkRunSummary? latest;

  @override
  Widget build(BuildContext context) {
    if (thread.hasLiveRun) {
      final color = _coworkStatusColor(thread.runStatus);
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (thread.runStatus == 'paused')
              Icon(Icons.pause_circle_outline, size: 14, color: color)
            else
              SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                thread.phase.ifEmpty('Working'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (thread.runStartedAt != null) ...<Widget>[
              const SizedBox(width: 7),
              _CoworkRunClock(since: thread.runStartedAt!, color: color),
            ],
          ],
        ),
      );
    }
    final status = thread.runStatus ?? latest?.status;
    if (status == null || status == 'pending') return const SizedBox.shrink();
    final color = status == 'failed'
        ? _danger
        : status == 'waiting_input'
        ? _warning
        : status == 'completed'
        ? _success
        : _textMuted;
    return _StatusPill(
      label: _titleCase(status.replaceAll('_', ' ')),
      color: color,
    );
  }
}

class _CoworkRunClock extends StatefulWidget {
  const _CoworkRunClock({required this.since, required this.color});

  final DateTime since;
  final Color color;

  @override
  State<_CoworkRunClock> createState() => _CoworkRunClockState();
}

class _CoworkRunClockState extends State<_CoworkRunClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final label = minutes >= 60
        ? '${elapsed.inHours}h ${minutes % 60}m'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
    return Text(
      label,
      style: GoogleFonts.geistMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: widget.color,
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
      tooltip: 'Computer used by this session',
      onSelected: (value) =>
          controller.updateCoworkChat(chat.id, <String, dynamic>{
            'deviceTargetOverride': value == 'default' ? null : value,
          }),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'default',
          child: Text(
            'Use Settings default (${device.setting == 'local' ? 'this device' : 'cloud'})',
          ),
        ),
        PopupMenuItem<String>(
          value: 'local',
          enabled: device.localAvailable,
          child: Text(
            device.localAvailable ? 'This device' : 'This device — unavailable',
          ),
        ),
        PopupMenuItem<String>(
          value: 'cloud',
          enabled: device.cloudAvailable,
          child: const Text('Cloud computer'),
        ),
      ],
      child: _CoworkContextPill(
        icon: local ? Icons.laptop_mac_rounded : Icons.cloud_outlined,
        label: local ? 'This device' : 'Cloud computer',
      ),
    );
  }
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
      dialogTitle: 'Choose a project folder',
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
          value: '__browse__',
          child: Text('Open folder…'),
        ),
        const PopupMenuItem<String>(
          value: '__default__',
          child: Text('Use default (NeoAgent Workspace)'),
        ),
        if (recents.isNotEmpty) const PopupMenuDivider(),
        for (final path in recents)
          PopupMenuItem<String>(
            value: path,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _coworkFolderName(path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  path,
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
    return Tooltip(
      message: widget.chat.workspacePathOverride ?? 'Default NeoAgent Workspace',
      child: KeyedSubtree(
        key: _anchorKey,
        child: _CoworkContextPill(
          icon: Icons.folder_outlined,
          label: widget.chat.workspaceLabel,
          accent: widget.chat.workspacePathOverride != null,
          onTap: _openMenu,
        ),
      ),
    );
  }
}

String _coworkFolderName(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? path : segments.last;
}

// ─── Starters (empty session) ────────────────────────────────────────────────

class _CoworkStarters extends StatelessWidget {
  const _CoworkStarters({required this.chat, required this.onPick});

  final CoworkChat chat;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final plan = chat.mode == CoworkInteractionMode.plan;
    final folder = chat.isLocal ? chat.workspaceLabel : 'the cloud workspace';
    final starters = <(IconData, String, String)>[
      (
        Icons.auto_stories_outlined,
        'Explain this project',
        'Read the folder and summarize the stack, entry points and how to run it.',
      ),
      (
        Icons.bug_report_outlined,
        'Find and fix a bug',
        'Reproduce the bug I describe, find the root cause and fix it with a regression test.',
      ),
      (
        Icons.science_outlined,
        'Add tests',
        'Add tests for the parts of this project that have the least coverage, then run them.',
      ),
      (
        Icons.rate_review_outlined,
        'Review uncommitted changes',
        'Run git diff, review the uncommitted changes for bugs and style issues, and summarize what you find.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - 48 - (columns - 1) * 10) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _LogoBadge(size: 40),
              const SizedBox(height: 14),
              Text(
                plan ? 'What should we plan?' : 'What should we build?',
                style: _displayTitleStyle(24),
              ),
              const SizedBox(height: 6),
              Text(
                chat.isLocal
                    ? 'Working in $folder on this device. NeoAgent reads and edits the folder directly and can run commands, open apps and use the screen.'
                    : 'Working in $folder on the cloud computer. NeoAgent reads and edits files there and can run commands and a browser.',
                style: TextStyle(color: _textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final starter in starters)
                    SizedBox(
                      width: cardWidth,
                      child: Material(
                        color: _bgSecondary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: () => onPick(starter.$3),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(starter.$1, size: 18, color: _accentHover),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        starter.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        starter.$3,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondary,
                                          height: 1.4,
                                        ),
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Transcript ──────────────────────────────────────────────────────────────

class _CoworkTranscript extends StatelessWidget {
  const _CoworkTranscript({
    required this.controller,
    required this.chat,
    required this.thread,
    required this.scrollController,
    required this.compact,
    required this.onOpenFile,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final CoworkThreadState thread;
  final ScrollController scrollController;
  final bool compact;
  final ValueChanged<String> onOpenFile;

  /// Interleaves each run's activity between the user request that started
  /// it and the assistant reply, so the transcript reads like a log of work.
  List<Widget> _blocks() {
    final blocks = <Widget>[];
    final emittedRuns = <String>{};
    void emitActivity(String? runId) {
      if (runId == null || runId.isEmpty || emittedRuns.contains(runId)) return;
      final items = thread.activityForRun(runId);
      if (items.isEmpty) return;
      emittedRuns.add(runId);
      blocks.add(
        _CoworkActivityGroup(
          key: ValueKey<String>('activity-$runId'),
          items: items,
          live: thread.hasLiveRun && thread.activeRunId == runId,
          onOpenFile: onOpenFile,
        ),
      );
    }

    for (final message in thread.messages) {
      if (message.role != 'user') emitActivity(message.runId);
      blocks.add(_CoworkMessageBubble(message: message));
      if (message.role == 'user' && message.metadata['steering'] != true) {
        emitActivity(message.runId);
      }
    }
    emitActivity(thread.activeRunId);
    // A run may have finished before its reply was persisted client-side.
    for (final item in thread.activity) {
      emitActivity(item.runId);
    }
    if (thread.streamingContent.trim().isNotEmpty) {
      blocks.add(
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
      );
    } else if (thread.hasLiveRun && thread.runStatus != 'paused') {
      blocks.add(_CoworkWorkingIndicator(phase: thread.phase));
    }
    for (final request in thread.inputRequests.where((item) => item.isPending)) {
      blocks.add(
        _CoworkInputCard(
          key: ValueKey<String>('input-${request.id}'),
          request: request,
          onSubmit: (answers) => controller.answerCoworkInput(request, answers),
        ),
      );
    }
    if (chat.mode == CoworkInteractionMode.plan &&
        !thread.hasLiveRun &&
        !thread.inputRequests.any((item) => item.isPending) &&
        thread.messages.any((message) => message.role == 'assistant')) {
      blocks.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: FilledButton.icon(
              onPressed: controller.implementSelectedCoworkPlan,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Implement this plan'),
            ),
          ),
        ),
      );
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 24,
        16,
        compact ? 14 : 24,
        12,
      ),
      children: _blocks(),
    );
  }
}

class _CoworkWorkingIndicator extends StatelessWidget {
  const _CoworkWorkingIndicator({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 4),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 10),
          Text(
            phase.ifEmpty('Working'),
            style: GoogleFonts.geistMono(fontSize: 12, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Activity ────────────────────────────────────────────────────────────────

class _CoworkActivityGroup extends StatefulWidget {
  const _CoworkActivityGroup({
    super.key,
    required this.items,
    required this.live,
    required this.onOpenFile,
  });

  final List<CoworkActivityItem> items;
  final bool live;
  final ValueChanged<String> onOpenFile;

  @override
  State<_CoworkActivityGroup> createState() => _CoworkActivityGroupState();
}

class _CoworkActivityGroupState extends State<_CoworkActivityGroup> {
  bool? _expanded;

  bool get expanded => _expanded ?? widget.live;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final edited = items
        .where((item) => item.isWriteTool && item.filePath != null)
        .map((item) => item.filePath!)
        .toSet();
    final commands = items.where((item) => item.isCommand).length;
    final failed = items.where((item) => item.isFailed).length;
    final totalMs = items.fold<int>(0, (sum, item) => sum + (item.durationMs ?? 0));
    final parts = <String>[
      '${items.length} ${items.length == 1 ? 'step' : 'steps'}',
      if (edited.isNotEmpty)
        '${edited.length} ${edited.length == 1 ? 'file' : 'files'} edited',
      if (commands > 0) '$commands ${commands == 1 ? 'command' : 'commands'}',
      if (failed > 0) '$failed failed',
      if (totalMs > 0 && !widget.live) _formatDuration(totalMs),
    ];
    final running = widget.live
        ? items.where((item) => item.isRunning).lastOrNull
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _bgSecondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.live ? _accent.withValues(alpha: 0.25) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.live)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    )
                  else
                    Icon(
                      failed > 0
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: failed > 0 ? _warning : _success,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      running != null && !expanded
                          ? _coworkActivityTitle(running)
                          : parts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: <Widget>[
                  for (final item in items)
                    _CoworkActivityRow(
                      key: ValueKey<String>(item.id),
                      item: item,
                      onOpenFile: widget.onOpenFile,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CoworkActivityRow extends StatefulWidget {
  const _CoworkActivityRow({
    super.key,
    required this.item,
    required this.onOpenFile,
  });

  final CoworkActivityItem item;
  final ValueChanged<String> onOpenFile;

  @override
  State<_CoworkActivityRow> createState() => _CoworkActivityRowState();
}

class _CoworkActivityRowState extends State<_CoworkActivityRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = item.isFailed
        ? _danger
        : item.isRunning
        ? _accent
        : _textMuted;
    final hasDetail = item.detail.trim().isNotEmpty;
    final path = item.filePath;
    final subtitle = item.isFailed
        ? item.summary
        : item.isCommand || item.isWriteTool
        ? ''
        : item.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: hasDetail ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: item.isRunning
                      ? SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: color,
                          ),
                        )
                      : Icon(_coworkActivityIcon(item), size: 15, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _coworkActivityTitle(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: item.isFailed ? _danger : _textPrimary,
                          fontFamily: item.isCommand || path != null
                              ? GoogleFonts.geistMono().fontFamily
                              : null,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty)
                        Text(
                          _condenseRunText(subtitle, maxLength: 160),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: _textMuted),
                        ),
                    ],
                  ),
                ),
                if (item.isWriteTool && path != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Open in workbench',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onOpenFile(path),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: _accentHover,
                        ),
                      ),
                    ),
                  ),
                ],
                if (item.durationMs != null && item.durationMs! > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(item.durationMs!),
                    style: GoogleFonts.geistMono(fontSize: 10.5, color: _textMuted),
                  ),
                ],
                if (hasDetail) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: _textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_open && hasDetail)
          Container(
            margin: const EdgeInsets.fromLTRB(30, 2, 6, 8),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: _bgTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                item.detail,
                style: GoogleFonts.geistMono(
                  fontSize: 11.5,
                  height: 1.45,
                  color: _textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _coworkClip(String text, int max) =>
    text.length > max ? '${text.substring(0, max)}\n…' : text;

/// Long-form output worth expanding for a finished tool step. File reads are
/// excluded on purpose: the transcript should not echo whole files.
String _coworkToolDetail(String toolName, dynamic result) {
  if (result is! Map) return '';
  if (toolName == 'execute_command') {
    final parts = <String>[
      for (final key in const <String>['stdout', 'output', 'stderr'])
        if (result[key]?.toString().trim().isNotEmpty ?? false)
          result[key].toString().trim(),
    ];
    return _coworkClip(parts.join('\n'), 6000);
  }
  if (result['error'] != null) {
    return _coworkClip(result['error'].toString(), 2000);
  }
  if (toolName == 'search_files' || toolName == 'code_navigate') {
    final results = result['results'] ?? result['matches'];
    if (results is List) {
      return _coworkClip(
        results
            .take(30)
            .map((entry) {
              if (entry is! Map) return entry.toString();
              final path = entry['path'] ?? entry['file'] ?? '';
              final line = entry['line'];
              return line == null ? '$path' : '$path:$line';
            })
            .join('\n'),
        3000,
      );
    }
  }
  if (toolName == 'list_directory') {
    final entries = result['entries'];
    if (entries is List) {
      return _coworkClip(
        entries
            .take(60)
            .map((entry) {
              if (entry is! Map) return entry.toString();
              final name = entry['name'] ?? entry['path'] ?? '';
              return entry['type'] == 'directory' ? '$name/' : '$name';
            })
            .join('\n'),
        3000,
      );
    }
  }
  return '';
}

String _coworkArg(CoworkActivityItem item, List<String> keys) {
  for (final key in keys) {
    final value = item.toolArgs[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _coworkActivityTitle(CoworkActivityItem item) {
  final path = item.filePath;
  switch (item.label) {
    case 'write_file':
      return 'Wrote ${path ?? 'a file'}';
    case 'edit_file' || 'replace_file_range':
      return 'Edited ${path ?? 'a file'}';
    case 'read_file':
      return 'Read ${path ?? 'a file'}';
    case 'read_files':
      final paths = item.toolArgs['paths'];
      final count = paths is List ? paths.length : 0;
      return count > 0 ? 'Read $count files' : 'Read files';
    case 'read_artifact':
      return 'Read an artifact';
    case 'list_directory':
      final target = path ?? '';
      return target.isEmpty || target == '.'
          ? 'Listed the workspace root'
          : 'Listed $target/';
    case 'search_files':
      final query = _coworkArg(item, <String>['query', 'pattern', 'glob']);
      return query.isEmpty ? 'Searched files' : 'Searched files for "$query"';
    case 'code_navigate':
      final query = _coworkArg(item, <String>['query', 'symbol']);
      return query.isEmpty ? 'Searched code' : 'Searched code for "$query"';
    case 'execute_command':
      final command = _coworkArg(item, <String>['command', 'cmd']);
      return command.isEmpty ? 'Ran a command' : '\$ ${_condenseRunText(command, maxLength: 140)}';
    case 'desktop_observe':
      return 'Looked at the screen';
    case 'desktop_click':
      final x = item.toolArgs['x'];
      final y = item.toolArgs['y'];
      return x == null || y == null ? 'Clicked' : 'Clicked at ($x, $y)';
    case 'desktop_drag':
      return 'Dragged on the screen';
    case 'desktop_scroll':
      return 'Scrolled';
    case 'desktop_type':
      return 'Typed text';
    case 'desktop_press_key':
      final key = _coworkArg(item, <String>['key', 'keys']);
      return key.isEmpty ? 'Pressed a key' : 'Pressed $key';
    case 'desktop_launch_app':
      final app = _coworkArg(item, <String>['app', 'name', 'bundleId']);
      return app.isEmpty ? 'Opened an app' : 'Opened $app';
    case 'desktop_get_tree':
      return 'Read the UI tree';
    case 'browser_navigate':
      final url = _coworkArg(item, <String>['url']);
      return url.isEmpty ? 'Opened a page' : 'Opened ${_condenseRunText(url, maxLength: 100)}';
    case 'browser_click':
      return 'Clicked in the browser';
    case 'browser_type':
      return 'Typed in the browser';
    case 'browser_extract':
      return 'Read the page';
    case 'browser_screenshot':
      return 'Captured the page';
    case 'browser_evaluate':
      return 'Ran a script in the page';
  }
  switch (item.kind) {
    case 'subagent':
      return 'Helper: ${_condenseRunText(item.summary, maxLength: 120)}';
    case 'verification':
      return 'Verified the result';
    case 'steering':
      return item.summary;
  }
  return _titleCase(item.label.replaceAll('_', ' '));
}

IconData _coworkActivityIcon(CoworkActivityItem item) {
  if (item.isFailed) return Icons.error_outline_rounded;
  if (item.isWriteTool) return Icons.edit_note_rounded;
  if (item.isCommand) return Icons.terminal_rounded;
  if (item.isDesktopTool) return Icons.desktop_windows_outlined;
  if (item.isBrowserTool) return Icons.language_outlined;
  switch (item.label) {
    case 'list_directory':
      return Icons.folder_open_outlined;
    case 'search_files' || 'code_navigate':
      return Icons.manage_search_rounded;
    case 'read_file' || 'read_files' || 'read_artifact':
      return Icons.description_outlined;
  }
  switch (item.kind) {
    case 'subagent':
      return Icons.account_tree_outlined;
    case 'verification':
      return Icons.verified_outlined;
    case 'steering':
      return Icons.alt_route_rounded;
  }
  return Icons.build_outlined;
}

// ─── Messages ────────────────────────────────────────────────────────────────

class _CoworkMessageBubble extends StatelessWidget {
  const _CoworkMessageBubble({required this.message});

  final ChatEntry message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final interim = message.metadata['interim'] == true;
    final steering = message.metadata['steering'] == true;
    final attachments = _jsonMapList(message.metadata['sharedAttachments']);
    final attachmentChips = attachments.isEmpty
        ? null
        : Wrap(
            spacing: 6,
            runSpacing: 6,
            children: attachments
                .map(
                  (attachment) => Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.attach_file_rounded, size: 15),
                    label: Text(attachment['name']?.toString() ?? 'Attachment'),
                  ),
                )
                .toList(growable: false),
          );

    if (user) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: _accentMuted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(color: _accent.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (steering)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'STEERING',
                      style: GoogleFonts.geistMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _accentHover,
                      ),
                    ),
                  ),
                SelectableText(
                  message.content,
                  style: TextStyle(color: _textPrimary, height: 1.5),
                ),
                if (attachmentChips != null) ...<Widget>[
                  const SizedBox(height: 8),
                  attachmentChips,
                ],
              ],
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _LogoBadge(size: 16),
              const SizedBox(width: 7),
              Text(
                interim
                    ? 'Progress'
                    : (message.senderName?.ifEmpty('NeoAgent') ?? 'NeoAgent'),
                style: GoogleFonts.geist(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              if (message.typing) ...<Widget>[
                const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: _accent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: interim
                ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                : const EdgeInsets.fromLTRB(4, 0, 12, 0),
            decoration: interim
                ? BoxDecoration(
                    color: _accentAlt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentAlt.withValues(alpha: 0.3)),
                  )
                : null,
            child: MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: interim ? _textSecondary : _textPrimary,
                ),
                code: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: GoogleFonts.geistMono().fontFamily,
                  fontSize: 12.5,
                  backgroundColor: _bgTertiary,
                ),
                codeblockDecoration: BoxDecoration(
                  color: _bgTertiary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquoteDecoration: BoxDecoration(
                  color: _bgTertiary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                h1: _displayTitleStyle(20),
                h2: _displayTitleStyle(18),
                h3: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (attachmentChips != null) ...<Widget>[
            const SizedBox(height: 8),
            attachmentChips,
          ],
        ],
      ),
    );
  }
}

// ─── Structured input ────────────────────────────────────────────────────────

class _CoworkInputCard extends StatefulWidget {
  const _CoworkInputCard({super.key, required this.request, required this.onSubmit});

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
  void initState() {
    super.initState();
    for (final question in widget.request.questions) {
      final recommended = question.options
          .where((option) => option.recommended)
          .firstOrNull;
      if (recommended != null) _answers[question.id] = recommended.label;
    }
  }

  @override
  void dispose() {
    for (final controller in _custom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complete = widget.request.questions.every(
      (question) => _answers[question.id]?.trim().isNotEmpty == true,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderColor: _warning.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.help_outline_rounded, size: 16, color: _warning),
                const SizedBox(width: 8),
                Text('NEOAGENT NEEDS A DECISION', style: _sectionEyebrowStyle()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The run is paused until you answer.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            for (final question in widget.request.questions) ...<Widget>[
              Text(question.header, style: Theme.of(context).textTheme.labelLarge),
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
                  decoration: const InputDecoration(
                    labelText: 'Or answer in your own words',
                  ),
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
              child: FilledButton.icon(
                onPressed: _submitting || !complete
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onSubmit(_answers);
                        if (mounted) setState(() => _submitting = false);
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_submitting ? 'Continuing…' : 'Continue run'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
