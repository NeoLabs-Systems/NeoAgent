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
                  appStrings.recentGroupDecisions,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  appStrings.whyArg1RepliedOrStayedQuiet(widget.agentName, platform.label),
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
                title: appStrings.couldNotLoadDecisions,
                body: formatCaughtError(snapshot.error!),
                action: TextButton(onPressed: _refresh, child: Text(appStrings.retry)),
              );
            }
            final entries = snapshot.data ?? const <BehaviorDecisionEntry>[];
            if (entries.isEmpty) {
              return _GroupDecisionsMessage(
                icon: Icons.forum_outlined,
                title: appStrings.noGroupMessagesYet,
                body:
                    appStrings.decisionsShowUpHereAsArg1(widget.agentName, platform.label),
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
          child: Text(appStrings.close),
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
    final bySystemOne = entries
        .where((entry) => entry.judgedBySystemOne)
        .length;
    final byLlm = entries.where((entry) => entry.judgedByLlm).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _DecisionPill(
          icon: Icons.reply_rounded,
          label: appStrings.arg1Replied(replied),
          color: _success,
        ),
        _DecisionPill(
          icon: Icons.volume_off_rounded,
          label: appStrings.arg1StayedQuiet(entries.length - replied),
          color: _textMuted,
        ),
        if (bySystemOne > 0)
          _DecisionPill(
            icon: Icons.bolt_rounded,
            label: appStrings.arg1ScoredBySystemOne(bySystemOne),
            color: _info,
          ),
        if (byLlm > 0)
          _DecisionPill(
            icon: Icons.psychology_outlined,
            label: appStrings.arg1JudgedByLlm(byLlm),
            color: _warning,
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
    // SystemOne's own verdict codes repeat what its score meters already show.
    final reasons = entry.reasonCodes
        .where(
          (code) =>
              !entry.judgedBySystemOne ||
              !const <String>{
                'system_one_gate',
                'agent_can_help',
                'hold_back',
              }.contains(code),
        )
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
                entry.spoke ? 'Replied' : appStrings.stayedQuiet,
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
              _DecisionJudgePill(entry: entry),
              ...reasons.map(
                (label) => _DecisionPill(label: label, color: _textSecondary),
              ),
            ],
          ),
          if (entry.judgedBySystemOne &&
              entry.systemOneSpeak != null) ...<Widget>[
            const SizedBox(height: 10),
            _SystemOneScores(entry: entry, agentName: agentName),
          ],
        ],
      ),
    );
  }
}

class _DecisionJudgePill extends StatelessWidget {
  const _DecisionJudgePill({required this.entry});

  final BehaviorDecisionEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.judgedBySystemOne) {
      return Tooltip(
        message: appStrings.systemOneScoredThisMessageDirectlyNo,
        child: _DecisionPill(
          icon: Icons.bolt_rounded,
          label: 'SystemOne',
          color: _info,
        ),
      );
    }
    if (entry.judgedByLlm) {
      return Tooltip(
        message: appStrings.aLanguageModelJudgedThisMessage,
        child: _DecisionPill(
          icon: Icons.psychology_outlined,
          label: 'LLM',
          color: _warning,
        ),
      );
    }
    return _DecisionPill(
      icon: Icons.rule_rounded,
      label: appStrings.rule,
      color: _textSecondary,
    );
  }
}

// SystemOne answers with probabilities, so its explanation is the scores
// themselves and how the need score compares with the reply threshold.
class _SystemOneScores extends StatelessWidget {
  const _SystemOneScores({required this.entry, required this.agentName});

  final BehaviorDecisionEntry entry;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final threshold = entry.needThreshold;
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: <Widget>[
        _ScoreMeter(
          label: appStrings.wantedAReplyFromArg1(agentName),
          value: entry.systemOneSpeak!,
        ),
        if (entry.systemOneForSomeoneElse != null)
          _ScoreMeter(
            label: appStrings.meantForSomeoneElse,
            value: entry.systemOneForSomeoneElse!,
          ),
        _ScoreMeter(
          label: threshold == null
              ? appStrings.needToReply
              : appStrings.needToReplyArg1ToSpeak((threshold * 100).round()),
          value: entry.needScore,
          marker: threshold,
          color: entry.spoke ? _success : _textMuted,
        ),
      ],
    );
  }
}

class _ScoreMeter extends StatelessWidget {
  const _ScoreMeter({
    required this.label,
    required this.value,
    this.marker,
    this.color,
  });

  final String label;
  final double value;
  final double? marker;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? _info;
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      width: 172,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(clamped * 100).round()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        color: _bgTertiary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Container(
                      width: width * clamped,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    if (marker != null)
                      Positioned(
                        left: (width * marker!.clamp(0.0, 1.0)) - 1,
                        top: -3,
                        bottom: -3,
                        child: Container(width: 2, color: _textPrimary),
                      ),
                  ],
                );
              },
            ),
          ),
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
      return appStrings.joiningIsOffHere;
    case 'behavior_disabled':
      return appStrings.socialBehaviorOff;
    case 'turn_taking_disabled':
      return appStrings.turnTakingOff;
    case 'reply_to_agent':
      return appStrings.replyToArg1(agentName);
    case 'addressed':
      return 'Tagged';
    case 'addressed_by_name':
      return appStrings.calledByName;
    case 'participation_always':
      return appStrings.alwaysJoins;
    case 'mention_only':
      return appStrings.tagsOnly;
    case 'agent_can_help':
      return appStrings.couldHelp;
    case 'hold_back':
      return appStrings.heldBack;
    case 'meant_for_someone_else':
      return appStrings.meantForSomeoneElse;
    case 'below_need_threshold':
      return appStrings.notNeededEnough;
    case 'prefer_hold_back':
      return appStrings.unclearWhoItWasFor;
    case 'model_unavailable':
      return appStrings.aiUnavailable;
    case 'system_one_unavailable':
      return appStrings.systemOneUnavailable;
    case 'parse_fallback':
      return appStrings.aiAnswerUnreadable;
    default:
      return code.replaceAll('_', ' ');
  }
}
