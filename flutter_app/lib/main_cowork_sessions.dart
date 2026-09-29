part of 'main.dart';

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
    if (thread.hasLiveRun || (chat.latestRun?.isLive ?? false)) return appStrings.running;
    if (chat.pendingInputCount > 0) return appStrings.needsInput;
    final now = DateTime.now();
    final updated = chat.updatedAt;
    if (updated.year == now.year &&
        updated.month == now.month &&
        updated.day == now.day) {
      return appStrings.today;
    }
    if (now.difference(updated).inDays < 7) return appStrings.thisWeek;
    return appStrings.earlier;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final chats = _filtered(controller.coworkChats);
    final buckets = <String, List<CoworkChat>>{};
    for (final chat in chats) {
      buckets.putIfAbsent(_bucket(chat), () => <CoworkChat>[]).add(chat);
    }
    final order = <String>[
      appStrings.running,
      appStrings.needsInput,
      appStrings.today,
      appStrings.thisWeek,
      appStrings.earlier,
    ];
    return _PanelSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(appStrings.sessions2, style: _sectionEyebrowStyle())),
                _CoworkIconChip(
                  tooltip: appStrings.newSessionN,
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
                hintText: appStrings.searchSessions,
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: _textMuted),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 16,
                        icon: Icon(Icons.close_rounded),
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
                title: appStrings.noSessionsYet,
                message: appStrings.startASessionToPlanOr,
                action: FilledButton.icon(
                  onPressed: () => unawaited(widget.onNew()),
                  icon: Icon(Icons.add_rounded, size: 18),
                  label: Text(appStrings.newSession),
                ),
              ),
            )
          else if (chats.isEmpty)
            Expanded(
              child: _CoworkEmpty(
                icon: Icons.search_off_rounded,
                title: appStrings.noMatches,
                message: appStrings.noSessionMatchesThatSearch,
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
                            color: bucket == appStrings.running
                                ? _success
                                : bucket == appStrings.needsInput
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
                              appStrings.arg1Arg2Arg36(chat.isLocal ? chat.workspaceLabel : 'Cloud', mode, _coworkRelativeTime(chat.updatedAt)),
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
                  tooltip: appStrings.sessionActions,
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
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: Text(appStrings.rename),
                    ),
                    PopupMenuItem<String>(
                      value: 'duplicate',
                      child: Text(appStrings.newSessionWithSameSetup),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(appStrings.delete),
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
      title: Text(appStrings.deleteSession),
      content: Text(
        appStrings.arg1AndItsRunHistoryWill(chat.title),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(appStrings.delete),
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
      title: Text(appStrings.renameSession),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 160,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text),
          child: Text(appStrings.rename),
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
