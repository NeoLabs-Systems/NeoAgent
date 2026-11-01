part of 'main.dart';

// Admin › Configuration: bring OpenClaw or Hermes Agent over from the server's
// computer, for installs without the CLI (`neoagent migrate`). The work is in
// src/agent_import_service.dart; this card shows what was found, collects the
// choices and shows the summary.

class _AdminImportCard extends StatefulWidget {
  const _AdminImportCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminImportCard> createState() => _AdminImportCardState();
}

class _AdminImportCardState extends State<_AdminImportCard>
    with _LoadSaveState<_AdminImportCard> {
  late final AgentImportService _service = AgentImportService(
    client: _client,
    baseUrl: _baseUrl,
    localRuntime: _supportsDesktopShell ? LocalRuntimeManager() : null,
    isLocalBackend: _controller.isLocalRuntimeBackend,
  );
  ImportSources? _found;
  ImportSelection? _selection;
  ImportSummary? _summary;
  bool _canRestart = false;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final found = await _service.fetchSources();
    _found = found;
    _selection = ImportSelection.everything(found);
    _summary = null;
    _canRestart = false;
  }

  Future<void> _run() async {
    final selection = _selection;
    if (selection == null || !selection.canRun || _saving) return;
    final ran = await _runSave(() async {
      final summary = await _service.run(selection);
      _canRestart =
          summary.restartRequired && await _service.canRestartServer();
      _summary = summary;
    }, appStrings.agentImportMovedIn);
    // The summary is the success message.
    if (ran && mounted) setState(() => _saveNotice = null);
  }

  Future<void> _restart() async {
    final restarted = await _runSave(
      _service.restartServer,
      appStrings.agentImportRestarted,
    );
    if (restarted && mounted) setState(() => _canRestart = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.agentImport,
      description: appStrings.agentImportDescription,
      child: _loadGate(_fetch) ?? _buildBody(),
    );
  }

  Widget _buildBody() {
    final found = _found;
    final selection = _selection;
    final summary = _summary;
    if (summary != null) {
      return _AdminImportSummaryView(
        summary: summary,
        canRestart: _canRestart,
        busy: _saving,
        onRestart: () => unawaited(_restart()),
        feedback: _saveFeedback(),
      );
    }
    if (found == null || selection == null || found.sources.isEmpty) {
      return Text(
        appStrings.agentImportNoneFound,
        style: TextStyle(color: _textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final source in found.sources)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selection.sourceIds.contains(source.id),
            onChanged: _saving
                ? null
                : (value) => setState(
                    () => selection.toggleSource(source.id, value == true),
                  ),
            title: Text('${source.label}  ·  ${source.path}'),
            subtitle: Text(
              <String>[
                ...source.contents.map(_importContentLine),
                if (source.needsHand > 0)
                  appStrings.agentImportNeedsHandCount(source.needsHand),
              ].join('\n'),
              style: TextStyle(color: _textMuted, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          appStrings.agentImportWhatComes,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          appStrings.agentImportAgentsAlways,
          style: TextStyle(color: _textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final part in found.offeredParts)
              FilterChip(
                label: Text(_importPartLabel(part)),
                selected: selection.parts.contains(part),
                onSelected: _saving
                    ? null
                    : (value) =>
                          setState(() => selection.togglePart(part, value)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingToggle(
          title: appStrings.agentImportFinish,
          subtitle: appStrings.agentImportFinishHint,
          value: selection.finish,
          onChanged: (value) => setState(() => selection.finish = value),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving || !selection.canRun
                ? null
                : () => unawaited(_run()),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.move_down_rounded, size: 18),
            label: Text(
              _saving
                  ? appStrings.agentImportRunning
                  : appStrings.agentImportRun,
            ),
          ),
        ),
        _saveFeedback(),
      ],
    );
  }
}

class _AdminImportSummaryView extends StatelessWidget {
  const _AdminImportSummaryView({
    required this.summary,
    required this.canRestart,
    required this.busy,
    required this.onRestart,
    required this.feedback,
  });

  final ImportSummary summary;
  final bool canRestart;
  final bool busy;
  final VoidCallback onRestart;
  final Widget feedback;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: _textMuted, fontSize: 12.5);
    final hidden = summary.attentionTotal - summary.attention.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          summary.broughtOver.isEmpty
              ? appStrings.agentImportAlreadyMovedIn
              : appStrings.agentImportMovedIn,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        for (final line in summary.broughtOver)
          _AdminImportLine(
            icon: Icons.check_rounded,
            color: _success,
            text: line,
          ),
        if (summary.broughtOver.isNotEmpty && summary.alreadyThere > 0)
          _AdminImportLine(
            icon: Icons.info_outline_rounded,
            color: _textMuted,
            text: appStrings.agentImportAlreadyThere(summary.alreadyThere),
          ),
        if (summary.attention.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            appStrings.agentImportNeedsHand,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final item in summary.attention)
            _AdminImportLine(
              icon: item.failed
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: item.failed ? _danger : _warning,
              text: '${item.kind} ${item.name}',
              detail: item.detail,
            ),
          if (hidden > 0)
            Text(appStrings.agentImportMore(hidden), style: muted),
        ],
        if (summary.finishTask case final task?) ...<Widget>[
          const SizedBox(height: 12),
          Text(appStrings.agentImportFinishQueued(task)),
        ],
        const SizedBox(height: 12),
        SelectableText(
          appStrings.agentImportReport(summary.reportFile),
          style: muted,
        ),
        if (summary.restartRequired) ...<Widget>[
          const SizedBox(height: 12),
          if (canRestart)
            FilledButton.icon(
              onPressed: busy ? null : onRestart,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(appStrings.restart),
            )
          else
            Text(appStrings.agentImportRestartNeeded),
        ],
        feedback,
      ],
    );
  }
}

class _AdminImportLine extends StatelessWidget {
  const _AdminImportLine({
    required this.icon,
    required this.color,
    required this.text,
    this.detail = '',
  });

  final IconData icon;
  final Color color;
  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                children: <InlineSpan>[
                  if (detail.isNotEmpty)
                    TextSpan(
                      text: ' — $detail',
                      style: TextStyle(color: _textMuted),
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

String _importPartLabel(String part) {
  return switch (part) {
    'keys' => appStrings.agentImportPartKeys,
    'memories' => appStrings.agentImportPartMemories,
    'skills' => appStrings.agentImportPartSkills,
    'model' => appStrings.agentImportPartModel,
    'tasks' => appStrings.agentImportPartTasks,
    'mcp' => appStrings.agentImportPartMcp,
    'channels' => appStrings.agentImportPartChannels,
    _ => part,
  };
}

// "3 skills: meal-planner, notes, …" for one part of a found install.
String _importContentLine(ImportContent content) {
  final names = content.names.take(4).join(', ');
  final more = content.names.length > 4 ? ', …' : '';
  final count = switch (content.part) {
    'agents' => appStrings.agentImportCountAgents(content.count),
    'keys' => appStrings.agentImportCountKeys(content.count),
    'memories' => <String>[
      appStrings.agentImportCountMemories(content.count),
      if (content.days > 0) appStrings.agentImportCountDays(content.days),
    ].join(', '),
    'skills' => appStrings.agentImportCountSkills(content.count),
    'model' => appStrings.agentImportPartModel,
    'tasks' => appStrings.agentImportCountTasks(content.count),
    'mcp' => appStrings.agentImportCountMcp(content.count),
    _ => appStrings.agentImportPartChannels,
  };
  return names.isEmpty ? count : '$count: $names$more';
}
