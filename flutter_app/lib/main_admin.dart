part of 'main.dart';

class AgentsPanel extends StatelessWidget {
  const AgentsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Agents',
          subtitle:
              'Create specialist bots with separate memory, settings, tools, and account assignments.',
          trailing: FilledButton.icon(
            onPressed: () => openAgentEditor(context, controller),
            icon: Icon(Icons.add),
            label: Text('Add Agent'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.agentProfiles.isEmpty)
          const _EmptyCard(
            title: 'No agents yet',
            subtitle: 'The main agent is created automatically when needed.',
          )
        else
          ...controller.agentProfiles.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              agent.displayName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (agent.isDefault)
                            _StatusPill(label: 'Default', color: _accentHover),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: agent.status,
                            color: agent.status == 'active'
                                ? _success
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${agent.slug}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (agent.description.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(agent.description),
                      ],
                      if (agent.responsibilities.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          agent.responsibilities,
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _communicationSummary(controller, agent),
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => controller.switchAgent(agent.id),
                            child: Text(
                              controller.selectedAgentId == agent.id
                                  ? 'Selected'
                                  : 'Switch',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => openAgentEditor(
                              context,
                              controller,
                              agent: agent,
                            ),
                            child: Text('Edit'),
                          ),
                          if (!agent.isDefault)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.makeAgentDefault(agent.id),
                              child: Text('Make default'),
                            ),
                          if (!agent.isMain && !agent.isDefault)
                            TextButton(
                              onPressed: () => _confirmDelete(
                                context,
                                title: 'Archive agent?',
                                message:
                                    'This hides "${agent.displayName}" from routing and selection.',
                                onConfirm: () =>
                                    controller.archiveAgent(agent.id),
                              ),
                              child: Text('Archive'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> openAgentEditor(
    BuildContext context,
    NeoAgentController controller, {
    AgentProfile? agent,
  }) async {
    final nameController = TextEditingController(
      text: agent?.displayName ?? '',
    );
    final slugController = TextEditingController(text: agent?.slug ?? '');
    final descriptionController = TextEditingController(
      text: agent?.description ?? '',
    );
    final responsibilitiesController = TextEditingController(
      text: agent?.responsibilities ?? '',
    );
    final instructionsController = TextEditingController(
      text: agent?.instructions ?? '',
    );
    var status = agent?.status ?? 'active';
    var canDelegate = agent?.canDelegate ?? false;
    var canBeDelegatedTo = agent?.canBeDelegatedTo ?? true;
    var restrictDelegateTargets =
        agent != null && agent.delegateTargets.isNotEmpty;
    final delegateTargets = <String>{...?agent?.delegateTargets};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(agent == null ? 'Add Agent' : 'Edit Agent'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onChanged: (value) {
                          if (agent == null && slugController.text.isEmpty) {
                            slugController.text = value
                                .trim()
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
                                .replaceAll(RegExp(r'^-+|-+$'), '');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: responsibilitiesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Responsibilities',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'paused',
                            child: Text('Paused'),
                          ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => status = value ?? 'active'),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Agent communication',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDelegate,
                        title: Text('Can delegate tasks to other agents'),
                        subtitle: Text(
                          'Use this for orchestrator agents. Leave off for isolated work bots that should finish direct messages themselves.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canDelegate = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canBeDelegatedTo,
                        title: Text('Can receive delegated tasks'),
                        subtitle: Text(
                          'Turn this off to keep this agent fully separate from other agents.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canBeDelegatedTo = value),
                      ),
                      if (canDelegate) ...<Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: restrictDelegateTargets,
                          title: Text('Restrict delegation targets'),
                          subtitle: Text(
                            restrictDelegateTargets
                                ? 'Only selected agents can receive tasks from this agent.'
                                : 'This agent can delegate to any eligible receiving agent.',
                          ),
                          onChanged: (value) => setLocalState(() {
                            restrictDelegateTargets = value;
                            if (!value) delegateTargets.clear();
                          }),
                        ),
                        if (restrictDelegateTargets) ...<Widget>[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller.agentProfiles
                                  .where((target) => target.id != agent?.id)
                                  .map((target) {
                                    final selected = delegateTargets.contains(
                                      target.id,
                                    );
                                    return FilterChip(
                                      label: Text(target.displayName),
                                      selected: selected,
                                      onSelected: (value) => setLocalState(() {
                                        if (value) {
                                          delegateTargets.add(target.id);
                                        } else {
                                          delegateTargets.remove(target.id);
                                        }
                                      }),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
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
                    final saved = await controller.saveAgentProfile(
                      id: agent?.id,
                      displayName: nameController.text.trim(),
                      slug: slugController.text.trim(),
                      description: descriptionController.text.trim(),
                      responsibilities: responsibilitiesController.text.trim(),
                      instructions: instructionsController.text.trim(),
                      status: status,
                      canDelegate: canDelegate,
                      canBeDelegatedTo: canBeDelegatedTo,
                      delegateTargets: restrictDelegateTargets
                          ? delegateTargets.toList(growable: false)
                          : const <String>[],
                    );
                    if (saved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _communicationSummary(
    NeoAgentController controller,
    AgentProfile agent,
  ) {
    final parts = <String>[];
    parts.add(
      agent.canDelegate
          ? (agent.delegatesToAnyEligibleAgent
                ? 'Can delegate to any receiving agent'
                : 'Can delegate to ${agent.delegateTargets.map(controller.agentLabelFor).join(', ')}')
          : 'Handles direct tasks itself',
    );
    parts.add(
      agent.canBeDelegatedTo
          ? 'can receive delegated tasks'
          : 'cannot receive delegated tasks',
    );
    return 'Agent communication: ${parts.join('; ')}.';
  }
}

class McpPanel extends StatelessWidget {
  const McpPanel({super.key, required this.controller, this.embedded = false});

  final NeoAgentController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: embedded ? EdgeInsets.zero : _pagePadding(context),
      children: <Widget>[
        if (!embedded)
          _PageTitle(
            title: 'MCP',
            subtitle: 'Configured MCP servers and live server status.',
            trailing: FilledButton.icon(
              onPressed: () => _openMcpEditor(context),
              icon: Icon(Icons.add),
              label: Text('Add Server'),
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => _openMcpEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Server'),
              ),
            ),
          ),
        if (controller.mcpServers.isEmpty)
          const _EmptyCard(
            title: 'No MCP servers configured',
            subtitle: 'Add an MCP server URL and choose an auth method.',
          )
        else
          ...controller.mcpServers.map(
            (server) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              server.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: server.status,
                            color: server.status == 'running'
                                ? _success
                                : server.hasError
                                ? _danger
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        server.command,
                        style: TextStyle(
                          fontFamily: GoogleFonts.geistMono().fontFamily,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _MetaPill(
                            label: server.enabled ? 'Enabled' : 'Disabled',
                            icon: Icons.toggle_on_outlined,
                          ),
                          _MetaPill(
                            label: '${server.toolCount} tools',
                            icon: Icons.build_outlined,
                          ),
                          _MetaPill(
                            label: server.authMethodLabel,
                            icon: Icons.lock_outline,
                          ),
                          _MetaPill(
                            label:
                                'Agent: ${controller.agentLabelFor(server.agentId)}',
                            icon: Icons.smart_toy_outlined,
                          ),
                        ],
                      ),
                      if (server.hasError) ...<Widget>[
                        const SizedBox(height: 12),
                        _InlineError(message: server.error!),
                        if (server.retryLabel.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            server.retryLabel,
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                _openMcpEditor(context, server: server),
                            child: Text('Edit'),
                          ),
                          if (server.status == 'running')
                            FilledButton(
                              onPressed: () =>
                                  controller.stopMcpServer(server.id),
                              child: Text('Stop'),
                            )
                          else
                            FilledButton(
                              onPressed: () =>
                                  controller.startMcpServer(server.id),
                              child: Text('Start'),
                            ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete MCP server?',
                              message:
                                  'This will remove "${server.name}" from the server list.',
                              onConfirm: () =>
                                  controller.deleteMcpServer(server.id),
                            ),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openMcpEditor(
    BuildContext context, {
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
                server == null ? 'Add MCP Server' : 'Edit MCP Server',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'MCP Server URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: authType,
                        decoration: const InputDecoration(
                          labelText: 'Auth Method',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(
                            value: 'bearer',
                            child: Text('Bearer Token'),
                          ),
                          DropdownMenuItem(
                            value: 'oauth',
                            child: Text('OAuth'),
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'Bearer Token',
                          ),
                        ),
                      ],
                      if (authType == 'oauth') ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: clientIdController,
                          decoration: const InputDecoration(
                            labelText: 'OAuth Client ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: authServerUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Auth Server URL',
                          ),
                        ),
                      ],
                      if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAgentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Agent',
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
                          'Matches the old NeoAgent MCP flow: URL plus auth method.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Start the server later from the list once the config is saved.',
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
                  child: Text('Cancel'),
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
                                'Failed to save MCP server.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
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
        const _PageTitle(
          title: 'Health',
          subtitle: 'Health Connect sync status and stored backend metrics.',
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Device access',
                value: deviceStatus == null
                    ? 'Checking...'
                    : !deviceStatus.available
                    ? 'Unavailable'
                    : deviceStatus.permissionsGranted
                    ? 'Ready'
                    : 'Permissions needed',
                helper:
                    deviceStatus?.message ??
                    'Reads steps, heart rate, sleep, exercise, and weight.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Backend sync',
                value: lastRun.isEmpty
                    ? 'No sync yet'
                    : lastSyncEmpty
                    ? 'No new data'
                    : '$lastRunRecordCount records',
                helper: lastRun.isEmpty
                    ? 'Sync once to seed your backend.'
                    : lastWindowEnd == null
                    ? 'Last window end is unknown.'
                    : 'Last window ended ${_formatTimestamp(lastWindowEnd)}',
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
                  label: Text('Request permissions'),
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
                  label: Text('Sync now'),
                ),
                _MetaPill(
                  label: 'Background sync stays scheduled on Android',
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
                const _SectionTitle('Last Sync Summary'),
                const SizedBox(height: 12),
                if (lastSummary.isEmpty)
                  Text(
                    'No detailed sync summary yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  if (lastSyncEmpty && metrics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lastWindowEnd == null
                            ? 'The latest sync completed successfully but did not find any new Health Connect records. Stored metrics below came from earlier syncs.'
                            : 'The latest sync window ended ${_formatTimestamp(lastWindowEnd)} and did not find any new Health Connect records. Stored metrics below came from earlier syncs.',
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
                        ? 'Last non-empty sync'
                        : 'Last non-empty sync · ${_formatTimestamp(lastNonEmptyWindowEnd)}',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHealthSummaryPills(lastNonEmptySummary),
                ],
                const SizedBox(height: 18),
                const _SectionTitle('Stored Metrics'),
                const SizedBox(height: 12),
                if (metrics.isEmpty)
                  Text('No health samples stored yet.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.whereType<Map<dynamic, dynamic>>().map((
                      map,
                    ) {
                      return _MetaPill(
                        icon: Icons.favorite_border,
                        label:
                            '${map['metricType']} · ${map['sampleCount']} samples',
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
