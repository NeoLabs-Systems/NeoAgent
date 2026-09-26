part of 'main.dart';

Future<void> _showGroupDecisionsDialog(
  BuildContext context, {
  required MessagingPlatformDescriptor platform,
  required String agentName,
  required Future<List<BehaviorDecisionEntry>> Function() onLoad,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _GroupDecisionsDialog(
      platform: platform,
      agentName: agentName,
      onLoad: onLoad,
    ),
  );
}

class _GroupDecisionsDialog extends StatefulWidget {
  const _GroupDecisionsDialog({
    required this.platform,
    required this.agentName,
    required this.onLoad,
  });

  final MessagingPlatformDescriptor platform;
  final String agentName;
  final Future<List<BehaviorDecisionEntry>> Function() onLoad;

  @override
  State<_GroupDecisionsDialog> createState() => _GroupDecisionsDialogState();
}

class _GroupDecisionsDialogState extends State<_GroupDecisionsDialog> {
  late Future<List<BehaviorDecisionEntry>> _decisions;

  @override
  void initState() {
    super.initState();
    _decisions = widget.onLoad();
  }

  void _refresh() {
    setState(() {
      _decisions = widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform;
    return AlertDialog(
      backgroundColor: _bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: platform.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.history_rounded, color: platform.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recent group decisions',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Why ${widget.agentName} replied or stayed quiet in ${platform.label} groups.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 480,
        child: FutureBuilder<List<BehaviorDecisionEntry>>(
          future: _decisions,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _GroupDecisionsMessage(
                icon: Icons.error_outline_rounded,
                title: 'Could not load decisions',
                body: formatCaughtError(snapshot.error!),
                action: TextButton(onPressed: _refresh, child: Text('Retry')),
              );
            }
            final entries = snapshot.data ?? const <BehaviorDecisionEntry>[];
            if (entries.isEmpty) {
              return _GroupDecisionsMessage(
                icon: Icons.forum_outlined,
                title: 'No group messages yet',
                body:
                    'Decisions show up here as ${widget.agentName} reads approved ${platform.label} groups. Only the latest 30 are kept, and they reset when the server restarts.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _GroupDecisionsSummary(entries: entries),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _GroupDecisionTile(
                      entry: entries[index],
                      agentName: widget.agentName,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class _GroupDecisionsSummary extends StatelessWidget {
  const _GroupDecisionsSummary({required this.entries});

  final List<BehaviorDecisionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final replied = entries.where((entry) => entry.spoke).length;
    final judged = entries.where((entry) => entry.askedModel).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _DecisionPill(
          icon: Icons.reply_rounded,
          label: '$replied replied',
          color: _success,
        ),
        _DecisionPill(
          icon: Icons.volume_off_rounded,
          label: '${entries.length - replied} stayed quiet',
          color: _textMuted,
        ),
        _DecisionPill(
          icon: Icons.psychology_outlined,
          label: '$judged judged by AI',
          color: _info,
        ),
      ],
    );
  }
}

class _GroupDecisionTile extends StatelessWidget {
  const _GroupDecisionTile({required this.entry, required this.agentName});

  final BehaviorDecisionEntry entry;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.spoke ? _success : _textMuted;
    final chatLabel = entry.chatName?.trim().isNotEmpty == true
        ? entry.serverName?.trim().isNotEmpty == true
              ? '${entry.serverName} › ${entry.chatName}'
              : entry.chatName!
        : entry.chatId;
    final reasons = entry.reasonCodes
        .where((code) => code != 'jev_gate')
        .map((code) => _decisionReasonLabel(code, agentName))
        .toSet();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                entry.spoke ? Icons.reply_rounded : Icons.volume_off_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                entry.spoke ? 'Replied' : 'Stayed quiet',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chatLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              Tooltip(
                message: entry.at.toString(),
                child: Text(
                  _coworkRelativeTime(entry.at),
                  style: TextStyle(color: _textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          if (entry.preview.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (entry.senderName?.trim().isNotEmpty == true)
                    TextSpan(
                      text: '${entry.senderName}: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: entry.preview),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(height: 1.35),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              entry.askedModel
                  ? _DecisionPill(
                      icon: Icons.psychology_outlined,
                      label:
                          'AI judged · ${(entry.needScore * 100).round()}% needed',
                      color: _info,
                    )
                  : _DecisionPill(
                      icon: Icons.rule_rounded,
                      label: 'Decided by rule',
                      color: _textSecondary,
                    ),
              ...reasons.map(
                (label) => _DecisionPill(label: label, color: _textSecondary),
              ),
            ],
          ),
          if (entry.askedModel && entry.rationale.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              entry.rationale,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionPill extends StatelessWidget {
  const _DecisionPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupDecisionsMessage extends StatelessWidget {
  const _GroupDecisionsMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: _textMuted),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, height: 1.35),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

String _decisionReasonLabel(String code, String agentName) {
  switch (code) {
    case 'untagged_disabled_for_shared_space':
      return 'Joining is off here';
    case 'behavior_disabled':
      return 'Social behavior off';
    case 'turn_taking_disabled':
      return 'Turn-taking off';
    case 'reply_to_agent':
      return 'Reply to $agentName';
    case 'addressed':
      return 'Tagged';
    case 'addressed_by_name':
      return 'Called by name';
    case 'participation_always':
      return 'Always joins';
    case 'mention_only':
      return 'Tags only';
    case 'agent_can_help':
      return 'Could help';
    case 'hold_back':
      return 'Held back';
    case 'meant_for_someone_else':
      return 'Meant for someone else';
    case 'below_need_threshold':
      return 'Not needed enough';
    case 'prefer_hold_back':
      return 'Unclear who it was for';
    case 'model_unavailable':
      return 'AI unavailable';
    case 'jev_unavailable':
      return 'JEV unavailable';
    case 'parse_fallback':
      return 'AI answer unreadable';
    default:
      return code.replaceAll('_', ' ');
  }
}
