part of 'main.dart';

/// The Agents settings page: the agents on the account, whether agents may
/// set up new ones, and the work they handed to each other.
class AgentsPanel extends StatefulWidget {
  const AgentsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AgentsPanel> createState() => _AgentsPanelState();

  static Future<void> openAgentEditor(
    BuildContext context,
    NeoAgentController controller, {
    AgentProfile? agent,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _AgentEditorDialog(controller: controller, agent: agent),
    );
  }
}

class _AgentsPanelState extends State<AgentsPanel> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshAgentTasks());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildPage(context, widget.controller),
    );
  }

  Widget _buildPage(BuildContext context, NeoAgentController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          anchor: 'agentList',
          title: appStrings.settingsYourAgents,
          description: appStrings.agentsPageIntro,
          trailing: FilledButton.icon(
            onPressed: () => AgentsPanel.openAgentEditor(context, controller),
            icon: const Icon(Icons.add, size: 18),
            label: Text(appStrings.addAgent),
          ),
          children: <Widget>[
            if (controller.agentProfiles.isEmpty)
              _SettingsBlock(
                child: _EmptyState(
                  title: appStrings.noAgentsYet,
                  subtitle: appStrings.theMainAgentIsCreatedAutomatically,
                ),
              ),
            for (final agent in controller.agentProfiles)
              _SettingsBlock(
                child: _AgentCard(controller: controller, agent: agent),
              ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.agentsCreationTitle,
          children: <Widget>[
            _SettingsRow(
              label: appStrings.agentsCreationLabel,
              description: switch (controller.agentCreationPolicy) {
                'deny' => appStrings.agentsCreationNeverHint,
                'allow' => appStrings.agentsCreationAllowHint,
                _ => appStrings.agentsCreationAskHint,
              },
              control: _SettingsChoice<String>(
                value: controller.agentCreationPolicy,
                options: <(String, String)>[
                  ('deny', appStrings.agentsCreationNever),
                  ('require_approval', appStrings.agentsCreationAsk),
                  ('allow', appStrings.agentsCreationAllow),
                ],
                onChanged: controller.setAgentCreationPolicy,
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.agentTasksTitle,
          description: appStrings.agentTasksDescription,
          children: <Widget>[
            if (controller.agentTasks.isEmpty)
              _SettingsBlock(
                child: _EmptyState(
                  title: appStrings.agentTasksEmpty,
                  subtitle: appStrings.agentTasksEmptyHint,
                ),
              ),
            for (final task in controller.agentTasks)
              _AgentTaskTile(
                key: ValueKey<String>(task.id),
                task: task,
                onStop: () => controller.cancelAgentTask(task.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.controller, required this.agent});

  final NeoAgentController controller;
  final AgentProfile agent;

  @override
  Widget build(BuildContext context) {
    final creator = agent.createdByAgentId == null
        ? null
        : controller.agentLabelFor(agent.createdByAgentId!);
    final notAllowed = _restrictionLabels(agent, 'deny');
    final asksFirst = _restrictionLabels(agent, 'require_approval');
    final selected = controller.selectedAgentId == agent.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                agent.displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (agent.isDefault)
              _StatusPill(label: appStrings.default2, color: _accentHover),
            if (agent.status != 'active') ...<Widget>[
              const SizedBox(width: 8),
              _StatusPill(label: appStrings.paused, color: _textSecondary),
            ],
          ],
        ),
        if (agent.responsibilities.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            appStrings.agentsResponsibleFor,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(agent.responsibilities),
        ],
        if (agent.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(agent.description, style: TextStyle(color: _textSecondary)),
        ],
        if (creator != null)
          _AgentNote(
            icon: Icons.auto_awesome_rounded,
            text: agent.creationReason.trim().isEmpty
                ? appStrings.agentsSetUpBy(creator)
                : appStrings.agentsSetUpByWithReason(
                    creator,
                    agent.creationReason.trim(),
                  ),
          ),
        if (notAllowed.isNotEmpty)
          _AgentNote(
            icon: Icons.block_rounded,
            text: appStrings.agentsNotAllowedList(notAllowed.join(', ')),
          ),
        if (asksFirst.isNotEmpty)
          _AgentNote(
            icon: Icons.front_hand_outlined,
            text: appStrings.agentsAsksFirstList(asksFirst.join(', ')),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: selected
                  ? null
                  : () => controller.switchAgent(agent.id),
              icon: Icon(
                selected ? Icons.check_rounded : Icons.chat_bubble_outline,
                size: 16,
              ),
              label: Text(
                selected ? appStrings.uxSelected : appStrings.agentsChat,
              ),
            ),
            OutlinedButton(
              onPressed: () => AgentsPanel.openAgentEditor(
                context,
                controller,
                agent: agent,
              ),
              child: Text(appStrings.edit),
            ),
            if (!agent.isDefault)
              OutlinedButton(
                onPressed: () => controller.makeAgentDefault(agent.id),
                child: Text(appStrings.makeDefault),
              ),
            if (!agent.isMain && !agent.isDefault)
              TextButton(
                onPressed: () => _confirmDelete(
                  context,
                  title: appStrings.archiveAgent,
                  message: appStrings.thisHidesArg1FromRoutingAnd(
                    agent.displayName,
                  ),
                  onConfirm: () => controller.archiveAgent(agent.id),
                ),
                child: Text(appStrings.archive),
              ),
          ],
        ),
      ],
    );
  }

  static List<String> _restrictionLabels(AgentProfile agent, String level) {
    return <String>[
      for (final entry in agent.toolRestrictions.entries)
        if (entry.value == level) _categoryInfo(entry.key).label,
    ];
  }
}

class _AgentNote extends StatelessWidget {
  const _AgentNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: _textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTaskTile extends StatefulWidget {
  const _AgentTaskTile({super.key, required this.task, required this.onStop});

  final AgentTask task;
  final VoidCallback onStop;

  @override
  State<_AgentTaskTile> createState() => _AgentTaskTileState();
}

class _AgentTaskTileState extends State<_AgentTaskTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final (statusLabel, statusColor) = _status(task);
    final outcome = task.status == 'completed' ? task.result : task.error;
    return _SettingsBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                task.isHandoff
                    ? Icons.swap_horiz_rounded
                    : Icons.subdirectory_arrow_right_rounded,
                size: 18,
                color: _textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.isHandoff
                      ? appStrings.agentTaskHandedOver(
                          task.requesterName,
                          task.ownerName,
                        )
                      : appStrings.agentTaskAsked(
                          task.requesterName,
                          task.ownerName,
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(task.goal, maxLines: _expanded ? null : 3),
          const SizedBox(height: 6),
          Text(
            _formatTimestamp(task.updatedAt),
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          if (_expanded && outcome.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: MarkdownBody(data: outcome, selectable: true),
            ),
          ],
          if (outcome.trim().isNotEmpty || task.isOpen) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (outcome.trim().isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? appStrings.agentTaskHideResult
                          : appStrings.agentTaskShowResult,
                    ),
                  ),
                if (task.isOpen)
                  TextButton(
                    onPressed: widget.onStop,
                    child: Text(appStrings.agentTaskStop),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static (String, Color) _status(AgentTask task) {
    if (task.isOpen && task.awaitingReply) {
      return (appStrings.agentTaskNeedsAnswer, _warning);
    }
    return switch (task.status) {
      'pending' => (appStrings.agentTaskQueued, _textSecondary),
      'working' => (appStrings.agentTaskWorking, _info),
      'waiting' => (appStrings.agentTaskWaiting, _warning),
      'completed' => (appStrings.agentTaskDone, _success),
      'failed' => (appStrings.agentTaskFailed, _danger),
      _ => (appStrings.agentTaskCancelled, _textSecondary),
    };
  }
}

/// Add or edit an agent. The essentials come first; how it works with other
/// agents and what it may do sit under "Advanced settings".
class _AgentEditorDialog extends StatefulWidget {
  const _AgentEditorDialog({required this.controller, this.agent});

  final NeoAgentController controller;
  final AgentProfile? agent;

  @override
  State<_AgentEditorDialog> createState() => _AgentEditorDialogState();
}

class _AgentEditorDialogState extends State<_AgentEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.agent?.displayName ?? '',
  );
  late final TextEditingController _slug = TextEditingController(
    text: widget.agent?.slug ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.agent?.description ?? '',
  );
  late final TextEditingController _responsibilities = TextEditingController(
    text: widget.agent?.responsibilities ?? '',
  );
  late final TextEditingController _instructions = TextEditingController(
    text: widget.agent?.instructions ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  late bool _slugEdited = widget.agent != null;
  late String _status = widget.agent?.status ?? 'active';
  late bool _canDelegate = widget.agent?.canDelegate ?? false;
  late bool _canBeDelegatedTo = widget.agent?.canBeDelegatedTo ?? true;
  late bool _restrictTargets =
      widget.agent?.delegateTargets.isNotEmpty ?? false;
  late final Set<String> _targets = <String>{
    ...?widget.agent?.delegateTargets,
  };
  late final Map<String, String> _restrictions = <String, String>{
    ...?widget.agent?.toolRestrictions,
  };
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _responsibilities.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _suggestSlug(String name) {
    if (_slugEdited) return;
    final suggested = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slug.text = suggested.length > 48 ? suggested.substring(0, 48) : suggested;
  }

  Future<void> _save() async {
    if (!_validateDialogForm(_formKey)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final controller = widget.controller;
    final saved = await controller.saveAgentProfile(
      id: widget.agent?.id,
      displayName: _name.text.trim(),
      slug: _slug.text.trim(),
      description: _description.text.trim(),
      responsibilities: _responsibilities.text.trim(),
      instructions: _instructions.text.trim(),
      status: _status,
      canDelegate: _canDelegate,
      canBeDelegatedTo: _canBeDelegatedTo,
      delegateTargets: _canDelegate && _restrictTargets
          ? _targets.toList(growable: false)
          : const <String>[],
      toolRestrictions: Map<String, String>.of(_restrictions),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveError = controller.errorMessage ?? appStrings.couldNotSaveAgent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(agent == null ? appStrings.addAgent : appStrings.editAgent),
      content: _ScrollableDialogBody(
        width: 720,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _name,
                autofocus: true,
                validator: (value) => value == null || value.trim().isEmpty
                    ? appStrings.agentNameRequired
                    : null,
                decoration: InputDecoration(labelText: appStrings.name),
                onChanged: _suggestSlug,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _responsibilities,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: appStrings.agentsResponsibleFor,
                  helperText: appStrings.agentsResponsibilityHint,
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: appStrings.description,
                  helperText: appStrings.agentsDescriptionHint,
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                title: Text(appStrings.uxAdvancedSettings),
                children: <Widget>[
                  TextField(
                    controller: _instructions,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: appStrings.instructions,
                      helperText: appStrings.optionalTheAgentAlreadyHasIts,
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _slug,
                    maxLength: 48,
                    decoration: InputDecoration(
                      labelText: appStrings.agentIdentifier,
                      counterText: '',
                      helperText: appStrings.agentIdentifierHint,
                      helperMaxLines: 3,
                    ),
                    onChanged: (_) => _slugEdited = _slug.text.isNotEmpty,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _status == 'active',
                      title: Text(appStrings.active),
                      onChanged: (value) => setState(
                        () => _status = value ? 'active' : 'paused',
                      ),
                    ),
                  _sectionTitle(context, appStrings.agentsWorkingWithOthers),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _canDelegate,
                    title: Text(appStrings.agentsCanHandOff),
                    subtitle: Text(appStrings.agentsCanHandOffHint),
                    onChanged: (value) => setState(() => _canDelegate = value),
                  ),
                  if (_canDelegate) ...<Widget>[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _restrictTargets,
                      title: Text(appStrings.agentsOnlyTheseAgents),
                      onChanged: (value) =>
                          setState(() => _restrictTargets = value == true),
                    ),
                    if (_restrictTargets)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final target in widget.controller.agentProfiles)
                            if (target.id != agent?.id)
                              FilterChip(
                                label: Text(target.displayName),
                                selected: _targets.contains(target.id),
                                onSelected: (value) => setState(() {
                                  if (value) {
                                    _targets.add(target.id);
                                  } else {
                                    _targets.remove(target.id);
                                  }
                                }),
                              ),
                        ],
                      ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _canBeDelegatedTo,
                    title: Text(appStrings.agentsCanTakeWork),
                    subtitle: Text(appStrings.agentsCanTakeWorkHint),
                    onChanged: (value) =>
                        setState(() => _canBeDelegatedTo = value),
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle(context, appStrings.agentsPermissionsTitle),
                  Text(
                    appStrings.agentsPermissionsHint,
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                  const SizedBox(height: 8),
                  for (final category in _kCategoryInfo.keys)
                    _AgentPermissionRow(
                      category: category,
                      level: _restrictions[category] ?? '',
                      onChanged: (level) => setState(() {
                        if (level.isEmpty) {
                          _restrictions.remove(category);
                        } else {
                          _restrictions[category] = level;
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        _DialogFormActions(
          busy: _saving,
          error: _saveError,
          submitLabel: appStrings.save,
          onSubmit: _save,
        ),
      ],
    );
  }

  static Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _AgentPermissionRow extends StatelessWidget {
  const _AgentPermissionRow({
    required this.category,
    required this.level,
    required this.onChanged,
  });

  final String category;

  /// '' follows the account, 'require_approval' asks first, 'deny' blocks.
  final String level;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo(category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(info.icon, size: 18, color: _textSecondary),
              const SizedBox(width: 8),
              Text(info.label),
            ],
          ),
          _SettingsChoice<String>(
            value: level,
            options: <(String, String)>[
              ('', appStrings.agentsPermissionAsAccount),
              ('require_approval', appStrings.agentsPermissionAskFirst),
              ('deny', appStrings.agentsPermissionNotAllowed),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Full MCP server controls, shown from the Tools page when a server row is
/// opened. Listens to the controller so status and errors stay live while the
/// detail sheet is on screen.
class McpServerDetailView extends StatelessWidget {
  const McpServerDetailView({
    super.key,
    required this.controller,
    required this.serverId,
  });

  final NeoAgentController controller;
  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final server = controller.mcpServers
            .where((item) => item.id == serverId)
            .firstOrNull;
        if (server == null) {
          return Text(
            appStrings.thisMcpServerIsNoLonger,
            style: TextStyle(color: _textSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(
              server.command,
              style: TextStyle(
                fontFamily: GoogleFonts.geistMono().fontFamily,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _StatusPill(
                  label: server.status,
                  color: server.status == 'running'
                      ? _success
                      : server.hasError
                      ? _danger
                      : _textSecondary,
                ),
                _MetaPill(
                  label: server.enabled ? 'Enabled' : 'Disabled',
                  icon: Icons.toggle_on_outlined,
                ),
                _MetaPill(
                  label: appStrings.arg1Tools(server.toolCount),
                  icon: Icons.build_outlined,
                ),
                _MetaPill(
                  label: server.authMethodLabel,
                  icon: Icons.lock_outline,
                ),
                _MetaPill(
                  label: appStrings.agentArg1(
                    controller.agentLabelFor(server.agentId),
                  ),
                  icon: Icons.smart_toy_outlined,
                ),
              ],
            ),
            if (server.hasError) ...<Widget>[
              const SizedBox(height: 14),
              _InlineError(message: server.error!),
              if (server.retryLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  server.retryLabel,
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (server.status == 'running')
                  FilledButton.icon(
                    onPressed: () => controller.stopMcpServer(server.id),
                    icon: Icon(Icons.stop_rounded),
                    label: Text(appStrings.stop),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => controller.startMcpServer(server.id),
                    icon: Icon(Icons.play_arrow_rounded),
                    label: Text(appStrings.start),
                  ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openMcpEditor(context, controller, server: server),
                  icon: Icon(Icons.edit_outlined),
                  label: Text(appStrings.edit),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(
                    context,
                    title: appStrings.deleteMcpServer,
                    message: appStrings.thisWillRemoveArg1FromThe(server.name),
                    onConfirm: () async {
                      await controller.deleteMcpServer(server.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  icon: Icon(Icons.delete_outline, color: _danger),
                  label: Text(
                    appStrings.delete,
                    style: TextStyle(color: _danger),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> _openMcpEditor(
  BuildContext context,
  NeoAgentController controller, {
  McpServerItem? server,
}) async {
  final nameController = TextEditingController(text: server?.name ?? '');
  final urlController = TextEditingController(text: server?.command ?? '');
  final auth = _jsonMap(server?.config['auth']);
  String authType = auth['type']?.toString().ifEmpty('none') ?? 'none';
  final tokenController = TextEditingController(
    text: auth['token']?.toString() ?? '',
  );
  final clientIdController = TextEditingController(
    text: auth['clientId']?.toString() ?? '',
  );
  final authServerUrlController = TextEditingController(
    text: auth['authServerUrl']?.toString() ?? '',
  );
  var enabled = server?.enabled ?? true;
  var selectedAgentId = server?.agentId ?? controller.selectedAgentId;
  if (selectedAgentId != null &&
      !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
    selectedAgentId = controller.selectedAgentId;
  }
  if (selectedAgentId != null &&
      !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
    selectedAgentId = controller.agentProfiles.isEmpty
        ? null
        : controller.agentProfiles.first.id;
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            backgroundColor: _bgCard,
            title: Text(
              server == null ? 'Add MCP Server' : appStrings.editMcpServer,
            ),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: appStrings.name),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: appStrings.mcpServerUrl,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: authType,
                      decoration: InputDecoration(
                        labelText: appStrings.authMethod,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'none',
                          child: Text(appStrings.none),
                        ),
                        DropdownMenuItem(
                          value: 'bearer',
                          child: Text(appStrings.bearerToken2),
                        ),
                        DropdownMenuItem(value: 'oauth', child: Text('OAuth')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocalState(() => authType = value);
                        }
                      },
                    ),
                    if (authType == 'bearer') ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        controller: tokenController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: appStrings.bearerToken2,
                        ),
                      ),
                    ],
                    if (authType == 'oauth') ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        controller: clientIdController,
                        decoration: InputDecoration(
                          labelText: appStrings.oauthClientId,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authServerUrlController,
                        decoration: InputDecoration(
                          labelText: appStrings.authServerUrl,
                        ),
                      ),
                    ],
                    if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAgentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: appStrings.assignedAgent2,
                        ),
                        items: controller.agentProfiles
                            .map(
                              (agent) => DropdownMenuItem<String>(
                                value: agent.id,
                                child: Text(agent.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setLocalState(() => selectedAgentId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        appStrings.matchesTheOldNeoagentMcpFlow,
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: enabled,
                      contentPadding: EdgeInsets.zero,
                      title: Text(appStrings.enabled),
                      onChanged: (value) =>
                          setLocalState(() => enabled = value),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        appStrings.startTheServerLaterFromThe,
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appStrings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final config = <String, dynamic>{
                    'auth': <String, dynamic>{
                      'type': authType,
                      if (authType == 'bearer' &&
                          tokenController.text.trim().isNotEmpty)
                        'token': tokenController.text.trim(),
                      if (authType == 'oauth' &&
                          clientIdController.text.trim().isNotEmpty)
                        'clientId': clientIdController.text.trim(),
                      if (authType == 'oauth' &&
                          authServerUrlController.text.trim().isNotEmpty)
                        'authServerUrl': authServerUrlController.text.trim(),
                    },
                  };
                  final saved = await controller.saveMcpServer(
                    id: server?.id,
                    name: nameController.text.trim(),
                    command: urlController.text.trim(),
                    config: config,
                    enabled: enabled,
                    agentId: selectedAgentId,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  if (saved) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.errorMessage ??
                              appStrings.failedToSaveMcpServer,
                        ),
                      ),
                    );
                  }
                },
                child: Text(appStrings.save),
              ),
            ],
          );
        },
      );
    },
  );
}

class HealthPanel extends StatelessWidget {
  const HealthPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final deviceStatus = controller.deviceHealthStatus;
    final backendStatus = controller.backendHealthStatus;
    final metrics = _jsonList(
      backendStatus?['metrics'],
      fallbackToMapValues: true,
    );
    final lastRun = _jsonMap(backendStatus?['lastRun']);
    final lastNonEmptyRun = _jsonMap(backendStatus?['lastNonEmptyRun']);
    final lastSummary = _jsonMap(lastRun['summary']);
    final lastNonEmptySummary = _jsonMap(lastNonEmptyRun['summary']);
    final lastRunRecordCount = _asInt(lastRun['record_count']);
    final lastSyncEmpty = lastRun.isNotEmpty && lastRunRecordCount == 0;
    final lastWindowEnd = _parseOptionalTimestamp(
      lastRun['sync_window_end']?.toString(),
    );
    final lastNonEmptyWindowEnd = _parseOptionalTimestamp(
      lastNonEmptyRun['sync_window_end']?.toString(),
    );

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Health',
          subtitle: appStrings.healthConnectSyncStatusAndStored,
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(
            message: controller.errorMessage!,
            onDismiss: controller.clearInlineError,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: appStrings.deviceAccess,
                value: deviceStatus == null
                    ? 'Checking...'
                    : !deviceStatus.available
                    ? 'Unavailable'
                    : deviceStatus.permissionsGranted
                    ? 'Ready'
                    : appStrings.permissionsNeeded,
                helper:
                    deviceStatus?.message ??
                    appStrings.readsStepsHeartRateSleepExercise,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: appStrings.backendSync,
                value: lastRun.isEmpty
                    ? appStrings.noSyncYet
                    : lastSyncEmpty
                    ? appStrings.noNewData
                    : appStrings.arg1Records(lastRunRecordCount),
                helper: lastRun.isEmpty
                    ? appStrings.syncOnceToSeedYourBackend
                    : lastWindowEnd == null
                    ? appStrings.lastWindowEndIsUnknown
                    : appStrings.lastWindowEndedArg1(
                        _formatTimestamp(lastWindowEnd),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.requestHealthPermissions,
                  icon: Icon(Icons.health_and_safety_outlined),
                  label: Text(appStrings.requestPermissions),
                ),
                FilledButton.icon(
                  onPressed: controller.isSyncingHealth
                      ? null
                      : controller.syncHealthNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentHover,
                    foregroundColor: _bgPrimary,
                  ),
                  icon: controller.isSyncingHealth
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.sync),
                  label: Text(appStrings.syncNow),
                ),
                _MetaPill(
                  label: appStrings.backgroundSyncStaysScheduledOnAndroid,
                  icon: Icons.sync_lock_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle(appStrings.lastSyncSummary),
                const SizedBox(height: 12),
                if (lastSummary.isEmpty)
                  Text(
                    appStrings.noDetailedSyncSummaryYet,
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  if (lastSyncEmpty && metrics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lastWindowEnd == null
                            ? 'The latest sync completed successfully but did not find any new Health Connect records. Stored metrics below came from earlier syncs.'
                            : appStrings.theLatestSyncWindowEndedArg1(
                                _formatTimestamp(lastWindowEnd),
                              ),
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                  _buildHealthSummaryPills(lastSummary),
                ],
                if (lastSyncEmpty &&
                    lastNonEmptySummary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    lastNonEmptyWindowEnd == null
                        ? appStrings.lastNonEmptySync
                        : appStrings.lastNonEmptySyncArg1(
                            _formatTimestamp(lastNonEmptyWindowEnd),
                          ),
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHealthSummaryPills(lastNonEmptySummary),
                ],
                const SizedBox(height: 18),
                _SectionTitle(appStrings.storedMetrics),
                const SizedBox(height: 12),
                if (metrics.isEmpty)
                  Text(appStrings.noHealthSamplesStoredYet)
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.whereType<Map<dynamic, dynamic>>().map((
                      map,
                    ) {
                      return _MetaPill(
                        icon: Icons.favorite_border,
                        label: appStrings.arg1Arg2Samples(
                          map['metricType'],
                          map['sampleCount'],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
