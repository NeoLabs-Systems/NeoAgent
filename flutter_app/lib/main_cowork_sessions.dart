part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cowork — sessions rail
// ─────────────────────────────────────────────────────────────────────────────

class _CoworkSessionRail extends StatefulWidget {
  const _CoworkSessionRail({
    required this.controller,
    required this.onNew,
    this.onSelect,
    this.onClose,
  });

  final NeoAgentController controller;
  final Future<void> Function() onNew;
  final VoidCallback? onSelect;
  final VoidCallback? onClose;

  @override
  State<_CoworkSessionRail> createState() => _CoworkSessionRailState();
}

class _CoworkSessionRailState extends State<_CoworkSessionRail> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CoworkChat> _filtered(List<CoworkChat> chats) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return chats;
    return chats
        .where(
          (chat) =>
              chat.title.toLowerCase().contains(query) ||
              chat.workspaceLabel.toLowerCase().contains(query) ||
              chat.agentName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  String _bucket(CoworkChat chat) {
    final thread = widget.controller.coworkThreadFor(chat.id);
    if (thread.hasLiveRun || (chat.latestRun?.isLive ?? false)) return 'Running';
    if (chat.pendingInputCount > 0) return 'Needs input';
    final now = DateTime.now();
    final updated = chat.updatedAt;
    if (updated.year == now.year &&
        updated.month == now.month &&
        updated.day == now.day) {
      return 'Today';
    }
    if (now.difference(updated).inDays < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final chats = _filtered(controller.coworkChats);
    final buckets = <String, List<CoworkChat>>{};
    for (final chat in chats) {
      buckets.putIfAbsent(_bucket(chat), () => <CoworkChat>[]).add(chat);
    }
    const order = <String>[
      'Running',
      'Needs input',
      'Today',
      'This week',
      'Earlier',
    ];
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              children: <Widget>[
                Expanded(child: Text('SESSIONS', style: _sectionEyebrowStyle())),
                _CoworkIconChip(
                  tooltip: 'New session (⌘N)',
                  icon: Icons.add_rounded,
                  size: 32,
                  onPressed: () {
                    unawaited(widget.onNew());
                    widget.onSelect?.call();
                  },
                ),
                if (widget.onClose != null) ...<Widget>[
                  const SizedBox(width: 6),
                  _CoworkIconChip(
                    tooltip: 'Close',
                    icon: Icons.close_rounded,
                    size: 32,
                    onPressed: widget.onClose!,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search sessions',
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: _textMuted),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 16,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                filled: true,
                fillColor: _bgCard.withValues(alpha: 0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderLight),
                ),
              ),
            ),
          ),
          if (controller.isLoadingCowork && controller.coworkChats.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.coworkChats.isEmpty)
            Expanded(
              child: _CoworkEmpty(
                title: 'No sessions yet',
                message: 'Start a session to plan or build with NeoAgent.',
                action: FilledButton.icon(
                  onPressed: () => unawaited(widget.onNew()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New session'),
                ),
              ),
            )
          else if (chats.isEmpty)
            const Expanded(
              child: _CoworkEmpty(
                icon: Icons.search_off_rounded,
                title: 'No matches',
                message: 'No session matches that search.',
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                children: <Widget>[
                  for (final bucket in order)
                    if (buckets.containsKey(bucket)) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                        child: Text(
                          bucket.toUpperCase(),
                          style: GoogleFonts.geistMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: bucket == 'Running'
                                ? _success
                                : bucket == 'Needs input'
                                ? _warning
                                : _textMuted,
                          ),
                        ),
                      ),
                      for (final chat in buckets[bucket]!)
                        _CoworkSessionRow(
                          controller: controller,
                          chat: chat,
                          selected: chat.id == controller.selectedCoworkChatId,
                          onTap: () {
                            unawaited(controller.selectCoworkChat(chat.id));
                            widget.onSelect?.call();
                          },
                        ),
                    ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CoworkSessionRow extends StatelessWidget {
  const _CoworkSessionRow({
    required this.controller,
    required this.chat,
    required this.selected,
    required this.onTap,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thread = controller.coworkThreadFor(chat.id);
    final status = thread.runStatus ?? chat.latestRun?.status;
    final live = thread.hasLiveRun || (chat.latestRun?.isLive ?? false);
    final mode = chat.mode == CoworkInteractionMode.plan ? 'Plan' : 'Agent';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _bgCard : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _borderLight : Colors.transparent,
              ),
            ),
            child: Row(
              children: <Widget>[
                _CoworkStatusDot(status: status, live: live),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            chat.isLocal
                                ? Icons.folder_outlined
                                : Icons.cloud_outlined,
                            size: 11,
                            color: _textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${chat.isLocal ? chat.workspaceLabel : 'Cloud'} · $mode · ${_coworkRelativeTime(chat.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.geistMono(
                                fontSize: 10.5,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Session actions',
                  iconSize: 18,
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        await _renameCoworkChat(context, controller, chat);
                      case 'duplicate':
                        await controller.createCoworkChat(template: chat);
                      case 'delete':
                        await _deleteCoworkChat(context, controller, chat);
                    }
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    PopupMenuItem<String>(
                      value: 'duplicate',
                      child: Text('New session with same setup'),
                    ),
                    PopupMenuDivider(),
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
      title: const Text('Delete session?'),
      content: Text(
        '“${chat.title}” and its run history will be permanently deleted. Any active run will be stopped. Files in the workspace are not touched.',
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
      title: const Text('Rename session'),
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
