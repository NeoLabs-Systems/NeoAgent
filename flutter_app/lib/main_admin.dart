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
              appStrings.createSpecialistBotsWithSeparateMemory,
          trailing: FilledButton.icon(
            onPressed: () => openAgentEditor(context, controller),
            icon: Icon(Icons.add),
            label: Text(appStrings.addAgent),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(
            message: controller.errorMessage!,
            onDismiss: controller.clearInlineError,
          ),
          const SizedBox(height: 16),
        ],
        if (controller.agentProfiles.isEmpty)
          _EmptyCard(
            title: appStrings.noAgentsYet,
            subtitle: appStrings.theMainAgentIsCreatedAutomatically,
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
                            child: Text(appStrings.edit),
                          ),
                          if (!agent.isDefault)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.makeAgentDefault(agent.id),
                              child: Text(appStrings.makeDefault),
                            ),
                          if (!agent.isMain && !agent.isDefault)
                            TextButton(
                              onPressed: () => _confirmDelete(
                                context,
                                title: appStrings.archiveAgent,
                                message:
                                    appStrings.thisHidesArg1FromRoutingAnd(agent.displayName),
                                onConfirm: () =>
                                    controller.archiveAgent(agent.id),
                              ),
                              child: Text(appStrings.archive),
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
              title: Text(agent == null ? 'Add Agent' : appStrings.editAgent),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: appStrings.name),
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
                        decoration: InputDecoration(
                          labelText: appStrings.description,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: responsibilitiesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: appStrings.responsibilities,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: appStrings.instructions,
                          helperText:
                              appStrings.optionalTheAgentAlreadyHasIts,
                          helperMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(labelText: appStrings.status),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(appStrings.active),
                          ),
                          DropdownMenuItem(
                            value: 'paused',
                            child: Text(appStrings.paused),
                          ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => status = value ?? 'active'),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          appStrings.agentCommunication,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDelegate,
                        title: Text(appStrings.canDelegateTasksToOtherAgents),
                        subtitle: Text(
                          appStrings.useThisForOrchestratorAgentsLeave,
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canDelegate = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canBeDelegatedTo,
                        title: Text(appStrings.canReceiveDelegatedTasks),
                        subtitle: Text(
                          appStrings.turnThisOffToKeepThis,
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canBeDelegatedTo = value),
                      ),
                      if (canDelegate) ...<Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: restrictDelegateTargets,
                          title: Text(appStrings.restrictDelegationTargets),
                          subtitle: Text(
                            restrictDelegateTargets
                                ? 'Only selected agents can receive tasks from this agent.'
                                : appStrings.thisAgentCanDelegateToAny,
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
                  child: Text(appStrings.cancel),
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
                    if (!context.mounted) return;
                    if (saved) {
                      Navigator.of(context).pop();
                    } else {
                      _showFormError(
                        context,
                        controller.errorMessage ?? appStrings.couldNotSaveAgent,
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

  static String _communicationSummary(
    NeoAgentController controller,
    AgentProfile agent,
  ) {
    final parts = <String>[];
    parts.add(
      agent.canDelegate
          ? (agent.delegatesToAnyEligibleAgent
                ? appStrings.canDelegateToAnyReceivingAgent
                : appStrings.canDelegateToArg1(agent.delegateTargets.map(controller.agentLabelFor).join(', ')))
          : appStrings.handlesDirectTasksItself,
    );
    parts.add(
      agent.canBeDelegatedTo
          ? appStrings.canReceiveDelegatedTasks2
          : appStrings.cannotReceiveDelegatedTasks,
    );
    return appStrings.agentCommunicationArg1(parts.join('; '));
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
                  label: appStrings.agentArg1(controller.agentLabelFor(server.agentId)),
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
                    message:
                        appStrings.thisWillRemoveArg1FromThe(server.name),
                    onConfirm: () async {
                      await controller.deleteMcpServer(server.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  icon: Icon(Icons.delete_outline, color: _danger),
                  label: Text(appStrings.delete, style: TextStyle(color: _danger)),
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
            title: Text(server == null ? 'Add MCP Server' : appStrings.editMcpServer),
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
                        DropdownMenuItem(value: 'none', child: Text(appStrings.none)),
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
                    : appStrings.lastWindowEndedArg1(_formatTimestamp(lastWindowEnd)),
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
                            : appStrings.theLatestSyncWindowEndedArg1(_formatTimestamp(lastWindowEnd)),
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
                        : appStrings.lastNonEmptySyncArg1(_formatTimestamp(lastNonEmptyWindowEnd)),
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
                        label:
                            appStrings.arg1Arg2Samples(map['metricType'], map['sampleCount']),
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
