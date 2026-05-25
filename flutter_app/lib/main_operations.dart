part of 'main.dart';

class LogsPanel extends StatefulWidget {
  const LogsPanel({super.key, required this.controller, this.embedded = false});

  final NeoAgentController controller;
  final bool embedded;

  @override
  State<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<LogsPanel> {
  static const JsonEncoder _debugJsonEncoder = JsonEncoder.withIndent('  ');
  bool _isExportingRecentMessages = false;

  String _recentLogsText() =>
      widget.controller.logs.map((log) => log.clipboardLine).join('\n');

  String _prettyJson(Object? value) => _debugJsonEncoder.convert(value);

  Future<Map<String, dynamic>?> _buildRunExport(
    String runId,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    if (runId.trim().isEmpty) {
      return null;
    }
    if (cache.containsKey(runId)) {
      return cache[runId];
    }
    try {
      final detail = await widget.controller.fetchRunDetail(runId);
      final payload = <String, dynamic>{
        'run': <String, dynamic>{
          'id': detail.run.id,
          'title': detail.run.title,
          'status': detail.run.status,
          'statusLabel': detail.run.statusLabel,
          'triggerSource': detail.run.triggerSource,
          'triggerLabel': detail.run.triggerLabel,
          'model': detail.run.model,
          'createdAt': detail.run.createdAt.toIso8601String(),
          'completedAt': detail.run.completedAt?.toIso8601String(),
          'durationLabel': detail.run.durationLabel,
          'totalTokens': detail.run.totalTokens,
          'error': detail.run.error,
        },
        'response': detail.response,
        'steps': detail.steps
            .map(
              (step) => <String, dynamic>{
                'id': step.id,
                'index': step.index,
                'displayIndex': step.displayIndex,
                'type': step.type,
                'status': step.status,
                'description': step.description,
                'toolName': step.toolName,
                'toolInput': step.toolInput,
                'result': step.result,
                'error': step.error,
                'tokensUsed': step.tokensUsed,
                'startedAt': step.startedAt?.toIso8601String(),
                'completedAt': step.completedAt?.toIso8601String(),
              },
            )
            .toList(),
      };
      cache[runId] = payload;
      return payload;
    } catch (error) {
      final payload = <String, dynamic>{
        'runId': runId,
        'error': error.toString(),
      };
      cache[runId] = payload;
      return payload;
    }
  }

  Future<String> _buildRecentMessagesExport() async {
    final controller = widget.controller;
    final recentMessages = controller.visibleChatMessages.reversed
        .take(5)
        .toList()
        .reversed
        .toList();
    final runCache = <String, Map<String, dynamic>>{};

    final messages = <Map<String, dynamic>>[];
    for (final entry in recentMessages) {
      final runId = entry.runId?.trim() ?? '';
      messages.add(<String, dynamic>{
        'id': entry.id,
        'role': entry.role,
        'content': entry.content,
        'platform': entry.platform,
        'senderName': entry.senderName,
        'createdAt': entry.createdAt.toIso8601String(),
        'transient': entry.transient,
        'runId': runId.isEmpty ? null : runId,
        'metadata': entry.metadata,
        'toolCalls': entry.toolCalls,
        if (runId.isNotEmpty)
          'runDetail': await _buildRunExport(runId, runCache),
      });
    }

    final export = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'kind': 'recent_chat_export',
      'messageCount': messages.length,
      'agent': <String, dynamic>{
        'id': controller.selectedAgentId,
        'label': controller.activeAgentLabel,
      },
      'liveRun': controller.activeRun == null
          ? null
          : <String, dynamic>{
              'runId': controller.activeRun!.runId,
              'title': controller.activeRun!.title,
              'model': controller.activeRun!.model,
              'phase': controller.activeRun!.phase,
              'iteration': controller.activeRun!.iteration,
              'pendingSteeringCount':
                  controller.activeRun!.pendingSteeringCount,
              'triggerSource': controller.activeRun!.triggerSource,
            },
      'liveToolEvents': controller.toolEvents
          .map(
            (event) => <String, dynamic>{
              'id': event.id,
              'toolName': event.toolName,
              'type': event.type,
              'status': event.status,
              'summary': event.summary,
            },
          )
          .toList(),
      'messages': messages,
    };
    return _prettyJson(export);
  }

  String _buildDebugInfo() {
    final controller = widget.controller;
    final now = DateTime.now().toIso8601String();
    final versionInfo = controller.versionInfo;
    final backendStatus = controller.backendHealthStatus;
    final lastRun = _jsonMap(backendStatus?['lastRun']);
    final lastNonEmptyRun = _jsonMap(backendStatus?['lastNonEmptyRun']);

    final snapshot = <String, dynamic>{
      'generatedAt': now,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'session': <String, dynamic>{
        'backendUrl': controller.backendUrl,
        'authenticated': controller.isAuthenticated,
        'socketConnected': controller.socketConnected,
        'selectedSection': controller.selectedSection.label,
        'account': controller.accountLabel,
      },
      'version': <String, dynamic>{
        'name': versionInfo?['name'],
        'version': versionInfo?['version'],
        'packageVersion': versionInfo?['packageVersion'],
        'gitVersion': versionInfo?['gitVersion'],
        'gitBranch': versionInfo?['gitBranch'],
        'gitSha': versionInfo?['gitSha'],
        'deploymentMode':
            versionInfo?['deploymentMode'] ??
            controller.updateStatus.deploymentMode,
        'deploymentProfile':
            versionInfo?['deploymentProfile'] ??
            controller.updateStatus.deploymentProfile,
        'allowSelfUpdate':
            versionInfo?['allowSelfUpdate'] ??
            controller.updateStatus.allowSelfUpdate,
        'releaseChannel':
            versionInfo?['releaseChannel'] ??
            controller.updateStatus.releaseChannel,
        'targetBranch':
            versionInfo?['targetBranch'] ??
            controller.updateStatus.targetBranch,
        'npmDistTag':
            versionInfo?['npmDistTag'] ?? controller.updateStatus.npmDistTag,
      },
      'ai': <String, dynamic>{
        'defaultChatModel': controller.defaultChatModel,
        'defaultSubagentModel': controller.defaultSubagentModel,
        'fallbackModel': controller.fallbackModel,
        'smarterSelector': controller.smarterSelector,
        'enabledModelCount': controller.enabledModelIds.length,
        'availableModelCount': controller.supportedModels
            .where((model) => model.available)
            .length,
        'providerStatus': controller.aiProviders
            .map(
              (provider) => <String, dynamic>{
                'id': provider.id,
                'enabled': provider.enabled,
                'available': provider.available,
                'status': provider.status,
                'statusLabel': provider.statusLabel,
                'modelCount': provider.modelCount,
                'availableModelCount': provider.availableModelCount,
                'baseUrl': provider.supportsBaseUrl ? provider.baseUrl : null,
                'credentialConfigured': provider.credentialConfigured,
              },
            )
            .toList(),
      },
      'runtime': <String, dynamic>{
        'headlessBrowser': controller.headlessBrowser,
        'browserBackend': controller.browserBackend,
        'browserExtensionConnected': controller.browserExtensionConnected,
        'hasLiveRun': controller.hasLiveRun,
        'activeRun': controller.activeRun == null
            ? null
            : <String, dynamic>{
                'runId': controller.activeRun!.runId,
                'title': controller.activeRun!.title,
                'model': controller.activeRun!.model,
                'phase': controller.activeRun!.phase,
                'iteration': controller.activeRun!.iteration,
                'pendingSteeringCount':
                    controller.activeRun!.pendingSteeringCount,
                'triggerSource': controller.activeRun!.triggerSource,
              },
      },
      'updateStatus': <String, dynamic>{
        'state': controller.updateStatus.state,
        'progress': controller.updateStatus.progress,
        'message': controller.updateStatus.message,
        'deploymentProfile': controller.updateStatus.deploymentProfile,
        'versionBefore': controller.updateStatus.versionBefore,
        'versionAfter': controller.updateStatus.versionAfter,
        'installedVersion': controller.updateStatus.installedVersion,
        'backendVersion': controller.updateStatus.backendVersion,
        'runtimeValidationReady':
            controller.updateStatus.runtimeValidationReady,
        'runtimeValidationIssues':
            controller.updateStatus.runtimeValidationIssues,
        'releaseChannel': controller.updateStatus.releaseChannel,
        'targetBranch': controller.updateStatus.targetBranch,
        'npmDistTag': controller.updateStatus.npmDistTag,
        'changelog': controller.updateStatus.changelog,
        'updateLogs': controller.updateStatus.logs,
      },
      'health': <String, dynamic>{
        'status': backendStatus?['status'],
        'timestamp': backendStatus?['timestamp'],
        'metricsCount': _jsonList(
          backendStatus?['metrics'],
          fallbackToMapValues: true,
        ).length,
        'lastRun': lastRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastRun['started_at'],
                'completedAt': lastRun['completed_at'],
                'recordCount': lastRun['record_count'],
                'syncWindowEnd': lastRun['sync_window_end'],
                'summary': _jsonMap(lastRun['summary']),
              },
        'lastNonEmptyRun': lastNonEmptyRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastNonEmptyRun['started_at'],
                'completedAt': lastNonEmptyRun['completed_at'],
                'recordCount': lastNonEmptyRun['record_count'],
                'syncWindowEnd': lastNonEmptyRun['sync_window_end'],
                'summary': _jsonMap(lastNonEmptyRun['summary']),
              },
      },
      'recentLogs': controller.logs
          .map(
            (log) => <String, dynamic>{
              'time': log.timeLabel,
              'type': log.type,
              'source': log.source,
              'message': log.message,
            },
          )
          .toList(),
    };

    return ['NeoAgent debug info', _prettyJson(snapshot)].join('\n\n');
  }

  Future<void> _copyLogs() async {
    final logsText = _recentLogsText();
    if (logsText.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: logsText));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied logs')));
  }

  Future<void> _copyDebugInfo() async {
    await Clipboard.setData(ClipboardData(text: _buildDebugInfo()));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied debug info')));
  }

  Future<void> _exportRecentMessages() async {
    if (_isExportingRecentMessages) {
      return;
    }
    setState(() => _isExportingRecentMessages = true);
    try {
      final exportText = await _buildRecentMessagesExport();
      await Clipboard.setData(ClipboardData(text: exportText));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied export for the last 5 messages')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: ${widget.controller.friendlyErrorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingRecentMessages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: widget.embedded ? EdgeInsets.zero : _pagePadding(context),
      children: <Widget>[
        if (!widget.embedded)
          _PageTitle(
            title: 'Logs',
            subtitle:
                'Merged server and Flutter runtime logs for this app session.',
            trailing: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _isExportingRecentMessages
                      ? null
                      : _exportRecentMessages,
                  icon: _isExportingRecentMessages
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.ios_share_outlined),
                  label: Text('Export last 5 messages'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyDebugInfo,
                  icon: Icon(Icons.bug_report_outlined),
                  label: Text('Copy debug info'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.logs.isEmpty ? null : _copyLogs,
                  icon: Icon(Icons.copy_all_outlined),
                  label: Text('Copy logs'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.clearLogs,
                  icon: Icon(Icons.clear_all),
                  label: Text('Clear'),
                ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _isExportingRecentMessages
                        ? null
                        : _exportRecentMessages,
                    icon: _isExportingRecentMessages
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_outlined),
                    label: const Text('Export last 5 messages'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyDebugInfo,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Copy debug info'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.controller.logs.isEmpty
                        ? null
                        : _copyLogs,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy logs'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.controller.clearLogs,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.controller.logs.isEmpty
                ? Text(
                    'Waiting for server or Flutter log output…',
                    style: TextStyle(color: _textSecondary),
                  )
                : Column(
                    children: widget.controller.logs.map((log) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '[${log.timeLabel}] ',
                                style: TextStyle(color: _textMuted),
                              ),
                              TextSpan(
                                text: '[${log.sourceLabel}] ',
                                style: TextStyle(color: _textSecondary),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(color: log.color),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class SkillsPanel extends StatefulWidget {
  const SkillsPanel({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final NeoAgentController controller;
  final bool embedded;

  @override
  State<SkillsPanel> createState() => _SkillsPanelState();
}

class _SkillsPanelState extends State<SkillsPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _searchController.text.trim().toLowerCase();
    final categories = <String>{
      'all',
      ...controller.storeSkills.map((item) => item.category),
    }.toList();
    final filteredStore =
        controller.storeSkills.where((item) {
          final matchesQuery =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query);
          final matchesCategory =
              _selectedCategory == 'all' || item.category == _selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList()..sort((a, b) {
          if (a.installed != b.installed) {
            return a.installed ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

    final body = Column(
      children: <Widget>[
        if (!widget.embedded)
          _PageTitle(
            title: 'Skills',
            subtitle:
                'Manage installed skills and browse the store. Official integrations live in their own section.',
            trailing: FilledButton.icon(
              onPressed: () => _openCreateSkill(context),
              icon: Icon(Icons.add),
              label: Text('New Skill'),
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => _openCreateSkill(context),
                icon: const Icon(Icons.add),
                label: const Text('New Skill'),
              ),
            ),
          ),
        if (!widget.embedded) const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: <Widget>[
              Tab(text: 'Installed Skills (${controller.skills.length})'),
              Tab(text: 'Store (${filteredStore.length})'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildInstalledTab(controller),
              _buildStoreTab(controller, categories, filteredStore),
            ],
          ),
        ),
      ],
    );
    if (widget.embedded) {
      return body;
    }
    return Padding(padding: _pagePadding(context), child: body);
  }

  Widget _buildInstalledTab(NeoAgentController controller) {
    if (controller.skills.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.extension_off_outlined,
                size: 34,
                color: _textSecondary,
              ),
              SizedBox(height: 12),
              Text(
                'No current skills yet. Install from Store or create a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: controller.skills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final skill = controller.skills[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                            ],
                          ),
                          Text(
                            skill.description.ifEmpty('No description'),
                            style: TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _MetaPill(
                                label: skill.category,
                                icon: Icons.folder_outlined,
                              ),
                              _MetaPill(
                                label: skill.source,
                                icon: Icons.source_outlined,
                              ),
                              if (skill.draft)
                                const _MetaPill(
                                  label: 'Draft',
                                  icon: Icons.edit_note_outlined,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  skill.description.ifEmpty('No description'),
                                  style: TextStyle(color: _textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _MetaPill(
                                      label: skill.category,
                                      icon: Icons.folder_outlined,
                                    ),
                                    _MetaPill(
                                      label: skill.source,
                                      icon: Icons.source_outlined,
                                    ),
                                    if (skill.draft)
                                      const _MetaPill(
                                        label: 'Draft',
                                        icon: Icons.edit_note_outlined,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: <Widget>[
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoreTab(
    NeoAgentController controller,
    List<String> categories,
    List<StoreSkillItem> filteredStore,
  ) {
    final featured = filteredStore.take(6).toList();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[_bgSecondary, _accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Skill Store',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Discover, install, and manage skills in a compact catalog.',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search skills',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == _selectedCategory;
                return FilterChip(
                  selected: selected,
                  label: Text(category == 'all' ? 'All' : category),
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          if (featured.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const _SectionTitle('Featured'),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = featured[index];
                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.installed ? _accentMuted : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(item.icon, style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            item.installed
                                ? _StatusPill(
                                    label: 'Installed',
                                    color: _success,
                                  )
                                : _StatusPill(label: 'Get', color: _info),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _textSecondary, height: 1.35),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const _SectionTitle('All Skills'),
              const Spacer(),
              Text(
                '${filteredStore.length} results',
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredStore.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No store skills match the current filter.',
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ...filteredStore.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 740;
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(item.icon, style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  label: item.installed ? 'Installed' : 'Get',
                                  color: item.installed ? _success : _info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: TextStyle(color: _textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                                const Spacer(),
                                item.installed
                                    ? OutlinedButton(
                                        onPressed: () => controller
                                            .uninstallStoreSkill(item.id),
                                        child: Text('Uninstall'),
                                      )
                                    : FilledButton(
                                        onPressed: () => controller
                                            .installStoreSkill(item.id),
                                        child: Text('Install'),
                                      ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Text(item.icon, style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSkillEditor(BuildContext context, String name) async {
    final document = await widget.controller.fetchSkillDocument(name);
    final contentController = TextEditingController(text: document.content);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(name),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(labelText: 'Skill Content'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.saveSkillContent(
                  name: name,
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateSkill(BuildContext context) async {
    final nameController = TextEditingController();
    final contentController = TextEditingController(
      text: '''---
name: New Skill
description: Describe what this skill does
---
Write the instructions for this skill here.
''',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('New Skill'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Filename'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 16,
                    maxLines: 24,
                    decoration: const InputDecoration(labelText: 'Content'),
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
                await widget.controller.createSkill(
                  filename: nameController.text.trim(),
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSkill(BuildContext context, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Delete skill?'),
          content: Text('"$name" will be removed permanently.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.controller.deleteSkill(name);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted "$name".')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete "$name": $error')),
      );
    }
  }
}

class MemoryPanel extends StatefulWidget {
  const MemoryPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MemoryPanel> createState() => _MemoryPanelState();
}

class _MemoryPanelState extends State<MemoryPanel> {
  late final TextEditingController _searchController;
  late final TextEditingController _llmPromptController;
  late final TextEditingController _llmImportController;
  final Set<String> _selectedMemoryIds = <String>{};
  bool _bulkActionInFlight = false;
  bool _llmPromptLoading = false;
  bool _llmImporting = false;
  bool _llmApplyBehaviorNotes = true;
  bool _llmApplyCoreMemory = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _llmPromptController = TextEditingController();
    _llmImportController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _llmPromptController.dispose();
    _llmImportController.dispose();
    super.dispose();
  }

  Future<void> _loadLlmPrompt(NeoAgentController controller) async {
    if (_llmPromptLoading) {
      return;
    }
    setState(() {
      _llmPromptLoading = true;
    });
    try {
      final prompt = await controller.fetchMemoryTransferPrompt();
      if (!mounted) {
        return;
      }
      setState(() {
        _llmPromptController.text = prompt;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate prompt: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _llmPromptLoading = false;
        });
      }
    }
  }

  Future<void> _copyLlmPrompt() async {
    final prompt = _llmPromptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prompt copied.')));
  }

  Future<void> _importLlmMemories(NeoAgentController controller) async {
    if (_llmImporting) {
      return;
    }
    final text = _llmImportController.text.trim();
    if (text.isEmpty) {
      return;
    }
    final confirmImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        final applyTargets = <String>[
          if (_llmApplyBehaviorNotes) 'behavior notes',
          if (_llmApplyCoreMemory) 'core memory',
          'memories',
        ];
        final targetLabel = applyTargets.join(', ');
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Import memory transfer?'),
          content: Text('This will import the response into $targetLabel.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Import'),
            ),
          ],
        );
      },
    );
    if (confirmImport != true) {
      return;
    }
    setState(() {
      _llmImporting = true;
    });
    try {
      final result = await controller.importMemoryTransfer(
        text,
        applyBehaviorNotes: _llmApplyBehaviorNotes,
        applyCoreMemory: _llmApplyCoreMemory,
      );
      if (!mounted) {
        return;
      }
      _llmImportController.clear();
      final warningText = result.warnings.isEmpty
          ? ''
          : ' ${result.warnings.join(' ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.importedCount} memories, '
            '${result.coreUpdatedCount} core entries.'
            '${result.behaviorNotesUpdated ? ' Behavior notes updated.' : ''}'
            '$warningText',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _llmImporting = false;
        });
      }
    }
  }

  List<MemoryItem> get _visibleMemories {
    final controller = widget.controller;
    return controller.memoryRecallResults.isNotEmpty
        ? controller.memoryRecallResults
        : controller.memories;
  }

  List<String> get _selectedVisibleMemoryIds {
    final visibleIds = _visibleMemories.map((memory) => memory.id).toSet();
    return _selectedMemoryIds
        .where(visibleIds.contains)
        .toList(growable: false);
  }

  void _toggleMemorySelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemoryIds.add(id);
      } else {
        _selectedMemoryIds.remove(id);
      }
    });
  }

  void _clearMemorySelection() {
    if (_selectedMemoryIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.clear();
    });
  }

  void _selectAllVisibleMemories(List<MemoryItem> memories) {
    if (memories.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.addAll(memories.map((memory) => memory.id));
    });
  }

  Future<void> _runMemorySearch(NeoAgentController controller) async {
    _clearMemorySelection();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      controller.clearMemorySearch();
    } else {
      await controller.searchMemories(query);
    }
  }

  void _resetMemorySearch(NeoAgentController controller) {
    _searchController.clear();
    _clearMemorySelection();
    controller.clearMemorySearch();
  }

  Future<void> _deleteSingleMemory(
    NeoAgentController controller,
    String id,
  ) async {
    await controller.deleteMemory(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedMemoryIds.remove(id);
    });
  }

  Future<void> _runBulkMemoryAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(List<String> ids) onConfirm,
  }) async {
    final ids = _selectedVisibleMemoryIds;
    if (ids.isEmpty || _bulkActionInFlight) {
      return;
    }
    await _confirmDelete(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: () async {
        setState(() {
          _bulkActionInFlight = true;
        });
        try {
          await onConfirm(ids);
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedMemoryIds.removeAll(ids);
          });
        } finally {
          if (mounted) {
            setState(() {
              _bulkActionInFlight = false;
            });
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final memoriesToShow = _visibleMemories;
    final selectedMemoryIds = _selectedVisibleMemoryIds.toSet();
    final selectedCount = selectedMemoryIds.length;
    final allVisibleSelected =
        memoriesToShow.isNotEmpty &&
        memoriesToShow.every((memory) => selectedMemoryIds.contains(memory.id));
    final showingSearchResults = controller.memoryRecallResults.isNotEmpty;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Memory',
          subtitle:
              'Structured facts, entities, reflections, long-term recall, and behavior notes.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _openBehaviorNotesEditor(context, controller),
                icon: Icon(Icons.edit_outlined),
                label: Text('Behavior Notes'),
              ),
              FilledButton.icon(
                onPressed: () => _openMemoryCreator(context, controller),
                icon: Icon(Icons.add),
                label: Text('Add Memory'),
              ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Active Memories',
                value: '${controller.memoryOverview.stats.active}',
                helper: 'Recallable long-term entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Extracted Facts',
                value: '${controller.memoryOverview.stats.facts}',
                helper: 'Structured statements for recall',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Entities',
                value: '${controller.memoryOverview.stats.entities}',
                helper: 'People, projects, files, and concepts',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Reflections',
                value: '${controller.memoryOverview.stats.knowledgeViews}',
                helper: 'Materialized knowledge views',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recall Search'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search memory',
                        ),
                        onSubmitted: (_) => _runMemorySearch(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _runMemorySearch(controller),
                      child: Text('Search'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _resetMemorySearch(controller),
                      child: Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Memory Intelligence'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _MetaPill(
                      label:
                          'Confidence ${(controller.memoryOverview.stats.averageConfidence * 100).round()}%',
                      icon: Icons.verified_outlined,
                    ),
                    _MetaPill(
                      label:
                          'Avg importance ${controller.memoryOverview.stats.averageImportance.toStringAsFixed(1)}',
                      icon: Icons.priority_high_outlined,
                    ),
                    _MetaPill(
                      label:
                          '${controller.memoryOverview.stats.ingestionDocuments} ingested docs',
                      icon: Icons.source_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (controller.memoryOverview.entities.isNotEmpty) ...<Widget>[
                  Text(
                    'Top entities',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: controller.memoryOverview.entities.map((entity) {
                      return _MetaPill(
                        label: entity.name,
                        icon: Icons.hub_outlined,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (controller
                    .memoryOverview
                    .knowledgeViews
                    .isNotEmpty) ...<Widget>[
                  Text(
                    'Reflections',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...controller.memoryOverview.knowledgeViews.take(5).map((
                    view,
                  ) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  view.title,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _MetaPill(
                                label: view.viewType,
                                icon: Icons.auto_stories_outlined,
                              ),
                            ],
                          ),
                          if (view.summary.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              view.summary,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                if (controller.memoryOverview.entities.isEmpty &&
                    controller.memoryOverview.knowledgeViews.isEmpty)
                  Text(
                    'No structured entities or reflections yet.',
                    style: TextStyle(color: _textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              leading: Icon(Icons.swap_horiz_outlined, color: _textSecondary),
              title: const _SectionTitle('LLM Memory Transfer'),
              subtitle: Text(
                'Export/import memories with another AI in one shot.',
                style: TextStyle(color: _textSecondary),
              ),
              children: <Widget>[
                Text(
                  'Generate a prompt to use in another AI, then paste the response here to import memories.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _llmPromptLoading
                          ? null
                          : () => _loadLlmPrompt(controller),
                      icon: Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        _llmPromptLoading ? 'Generating...' : 'Generate Prompt',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _llmPromptController.text.trim().isEmpty
                          ? null
                          : _copyLlmPrompt,
                      icon: Icon(Icons.copy_all_outlined),
                      label: Text('Copy Prompt'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _llmPromptController,
                  minLines: 6,
                  maxLines: 10,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Prompt to paste into another AI',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _llmApplyBehaviorNotes,
                  onChanged: _llmImporting
                      ? null
                      : (value) {
                          setState(() {
                            _llmApplyBehaviorNotes = value;
                          });
                        },
                  title: Text('Apply behavior notes'),
                  subtitle: Text(
                    'Overwrite assistant behavior notes from the import.',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _llmApplyCoreMemory,
                  onChanged: _llmImporting
                      ? null
                      : (value) {
                          setState(() {
                            _llmApplyCoreMemory = value;
                          });
                        },
                  title: Text('Apply core memory'),
                  subtitle: Text(
                    'Update core memory key/value entries from the import.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Paste the response from the other AI below, then import.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _llmImportController,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'LLM memory export response',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _llmImporting
                      ? null
                      : () => _importLlmMemories(controller),
                  icon: Icon(Icons.file_download_outlined),
                  label: Text(_llmImporting ? 'Importing...' : 'Import'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _SectionTitle('Core Memory')),
                    TextButton.icon(
                      onPressed: () =>
                          _openCoreMemoryEditor(context, controller),
                      icon: Icon(Icons.add),
                      label: Text('Add Entry'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.memoryOverview.coreEntries.isEmpty)
                  Text(
                    'No core memory entries yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryOverview.coreEntries.entries.map((entry) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.key,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(entry.value.toString()),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCoreMemoryEditor(
                              context,
                              controller,
                              keyValue: entry,
                            ),
                            icon: Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete core memory entry?',
                              message:
                                  'Remove "${entry.key}" from core memory.',
                              onConfirm: () =>
                                  controller.deleteCoreMemory(entry.key),
                            ),
                            icon: Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Memories'),
                const SizedBox(height: 6),
                Text(
                  showingSearchResults
                      ? 'Showing search results. Select memories to archive or delete them together.'
                      : 'Select one or more memories to archive or delete them together.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 10),
                if (memoriesToShow.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: allVisibleSelected || _bulkActionInFlight
                            ? null
                            : () => _selectAllVisibleMemories(memoriesToShow),
                        icon: Icon(Icons.done_all_outlined),
                        label: Text(
                          allVisibleSelected ? 'All Selected' : 'Select All',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedCount == 0 || _bulkActionInFlight
                            ? null
                            : _clearMemorySelection,
                        icon: Icon(Icons.deselect_outlined),
                        label: Text('Clear Selection'),
                      ),
                      if (selectedCount > 0)
                        FilledButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Archive selected memories?',
                                  message:
                                      'Archive $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'}? Archived memories are removed from the main list.',
                                  confirmLabel: 'Archive',
                                  onConfirm: controller.archiveMemories,
                                ),
                          icon: Icon(Icons.archive_outlined),
                          label: Text('Archive ($selectedCount)'),
                        ),
                      if (selectedCount > 0)
                        OutlinedButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Delete selected memories?',
                                  message:
                                      'Delete $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'} permanently?',
                                  confirmLabel: 'Delete',
                                  onConfirm: controller.deleteMemories,
                                ),
                          icon: Icon(Icons.delete_sweep_outlined),
                          label: Text('Delete ($selectedCount)'),
                        ),
                    ],
                  ),
                if (selectedCount > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (memoriesToShow.isNotEmpty) const SizedBox(height: 10),
                if (memoriesToShow.isEmpty)
                  Text(
                    'No memory entries found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...memoriesToShow.map((memory) {
                    final isSelected = selectedMemoryIds.contains(memory.id);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _accentMuted : _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _accent : _border,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              _toggleMemorySelection(memory.id, !isSelected),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) => _toggleMemorySelection(
                                    memory.id,
                                    value ?? false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: <Widget>[
                                                _MetaPill(
                                                  label: memory.category,
                                                  icon: Icons.label_outline,
                                                ),
                                                _MetaPill(
                                                  label:
                                                      'Importance ${memory.importance}',
                                                  icon: Icons
                                                      .priority_high_outlined,
                                                ),
                                                _MetaPill(
                                                  label:
                                                      'Confidence ${memory.confidencePercent}%',
                                                  icon: Icons.verified_outlined,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _bulkActionInFlight
                                                ? null
                                                : () => _confirmDelete(
                                                    context,
                                                    title: 'Delete memory?',
                                                    message:
                                                        'This memory entry will be removed permanently.',
                                                    onConfirm: () =>
                                                        _deleteSingleMemory(
                                                          controller,
                                                          memory.id,
                                                        ),
                                                  ),
                                            icon: Icon(Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(memory.content),
                                      if (memory
                                          .entities
                                          .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: memory.entities.take(6).map(
                                            (entity) {
                                              return _MetaPill(
                                                label: entity.name,
                                                icon: Icons.hub_outlined,
                                              );
                                            },
                                          ).toList(),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        memory.createdAtLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondary,
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
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recent Conversations'),
                const SizedBox(height: 10),
                if (controller.memoryConversations.isEmpty)
                  Text(
                    'No recent conversations found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryConversations.map(
                    (conversation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              conversation.title,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              conversation.preview,
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMemoryCreator(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController();
    final importanceController = TextEditingController(text: '5');
    String category = 'episodic';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Add Memory'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'episodic',
                      child: Text('episodic'),
                    ),
                    DropdownMenuItem(
                      value: 'user_fact',
                      child: Text('user_fact'),
                    ),
                    DropdownMenuItem(
                      value: 'preference',
                      child: Text('preference'),
                    ),
                    DropdownMenuItem(
                      value: 'personality',
                      child: Text('personality'),
                    ),
                  ],
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: (value) {
                    if (value != null) {
                      category = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importanceController,
                  decoration: const InputDecoration(labelText: 'Importance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.createMemory(
                  content: contentController.text.trim(),
                  category: category,
                  importance:
                      int.tryParse(importanceController.text.trim()) ?? 5,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBehaviorNotesEditor(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController(
      text: controller.memoryOverview.assistantBehaviorNotes,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Edit Assistant Behavior Notes'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(
                labelText: 'assistant_behavior_notes',
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
                await controller.updateAssistantBehaviorNotes(
                  contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCoreMemoryEditor(
    BuildContext context,
    NeoAgentController controller, {
    MapEntry<String, dynamic>? keyValue,
  }) async {
    final keyController = TextEditingController(text: keyValue?.key ?? '');
    final valueController = TextEditingController(
      text: keyValue?.value?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(
            keyValue == null
                ? 'Add Core Memory Entry'
                : 'Edit Core Memory Entry',
          ),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateCoreMemory(
                  keyController.text.trim(),
                  valueController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class WidgetsPanel extends StatelessWidget {
  const WidgetsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Widgets',
          subtitle:
              'Beautiful, glanceable AI widgets that stay in sync across the app, launcher, and Android home screen.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.refreshWidgets,
                icon: Icon(Icons.refresh_rounded),
                label: Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: controller.openWidgetCreateFlow,
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Create With AI'),
              ),
            ],
          ),
        ),
        if (controller.widgets.isEmpty)
          const _EmptyCard(
            title: 'No AI widgets yet',
            subtitle:
                'Create a widget through the agent and it will appear here, in launcher mode, and in Android home widgets.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = constraints.maxWidth >= 1100 ? 18.0 : 0.0;
              final columns = constraints.maxWidth >= 1400
                  ? 2
                  : (constraints.maxWidth >= 920 ? 2 : 1);
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final cardWidth = columns == 1
                  ? width
                  : (width - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: controller.widgets.map((item) {
                  final remaining = controller.widgetRunCooldownSeconds(
                    item.id,
                  );
                  return SizedBox(
                    width: cardWidth,
                    child: _AiWidgetCard(
                      item: item,
                      controller: controller,
                      active: controller.selectedWidgetId == item.id,
                      onSelect: () => controller.selectWidget(item.id),
                      footer: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          if (!item.isSystem)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.openWidgetEditFlow(item),
                              child: Text('Edit With AI'),
                            ),
                          if (!item.isSystem)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.toggleWidgetEnabled(item),
                              child: Text(item.enabled ? 'Pause' : 'Enable'),
                            ),
                          FilledButton(
                            onPressed: remaining > 0
                                ? null
                                : () => controller.refreshWidgetNow(item.id),
                            child: Text(
                              _manualRunButtonLabel('Run Now', remaining),
                            ),
                          ),
                          if (!item.isSystem)
                            OutlinedButton(
                              onPressed: () => _confirmDelete(
                                context,
                                title: 'Delete widget?',
                                message:
                                    'This removes "${item.name}" and its refresh job.',
                                onConfirm: () =>
                                    controller.deleteWidget(item.id),
                              ),
                              child: Text('Delete'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _AiWidgetCard extends StatefulWidget {
  const _AiWidgetCard({
    required this.item,
    this.controller,
    this.footer,
    this.active = false,
    this.compact = false,
    this.onSelect,
  });

  final AiWidgetItem item;
  final NeoAgentController? controller;
  final Widget? footer;
  final bool active;
  final bool compact;
  final VoidCallback? onSelect;

  @override
  State<_AiWidgetCard> createState() => _AiWidgetCardState();
}

class _AiWidgetCardState extends State<_AiWidgetCard> {
  bool _expandedTasks = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final controller = widget.controller;
    final active = widget.active;
    final compact = widget.compact;
    final onSelect = widget.onSelect;
    final footer = widget.footer;
    final snapshot = item.latestSnapshot;
    final accent = _widgetAccentColor(
      snapshot?.accentToken ?? item.template,
      surfaceColor: snapshot?.surfaceColor ?? '',
    );
    final icon = _widgetIconData(snapshot?.iconToken ?? item.template);
    final displayName = _widgetDisplayName(item.name);
    final title = _widgetPrimaryTitle(item, snapshot);
    final subtitle = _widgetSecondaryTitle(item, snapshot);
    final metric = snapshot?.metric ?? '';
    final rows = snapshot?.rows ?? const <Map<String, dynamic>>[];
    final chips = snapshot?.chips ?? const <String>[];
    final body = _widgetSummaryText(item, snapshot);
    final updatedLabel = snapshot?.generatedAtLabel ?? item.lastSnapshotLabel;
    final cadenceLabel = _widgetCadenceLabel(item.refreshCron);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              _bgCard,
              accent,
              compact ? 0.14 : 0.18,
            )!.withValues(alpha: 0.98),
            _bgCard.withValues(alpha: 0.98),
            _bgSecondary.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.42) : _border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: compact ? 0.1 : 0.14),
            blurRadius: compact ? 22 : 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 28 : 32),
          onTap: onSelect,
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AiWidgetAndroidPreview(
                        item: item,
                        accent: accent,
                        icon: icon,
                        snapshot: snapshot,
                        compact: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.26),
                              ),
                            ),
                            child: Icon(icon, color: accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 24,
                                    height: 1.06,
                                    letterSpacing: -0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusPill(
                            label: item.isSystem
                                ? (item.enabled
                                      ? 'System live'
                                      : 'System paused')
                                : (item.enabled ? 'Live' : 'Paused'),
                            color: item.enabled ? _success : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 860;
                          final infoPane = _AiWidgetInfoPane(
                            item: item,
                            snapshot: snapshot,
                            accent: accent,
                            title: title,
                            subtitle: subtitle,
                            body: body,
                            metric: metric,
                            rows: rows,
                            chips: chips,
                            cadenceLabel: cadenceLabel,
                            updatedLabel: updatedLabel,
                          );
                          final previewPane = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Preview',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AiWidgetAndroidPreview(
                                item: item,
                                accent: accent,
                                icon: icon,
                                snapshot: snapshot,
                              ),
                            ],
                          );
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                infoPane,
                                const SizedBox(height: 20),
                                previewPane,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 11, child: infoPane),
                              const SizedBox(width: 20),
                              Expanded(flex: 10, child: previewPane),
                            ],
                          );
                        },
                      ),
                      if (item.hasError) ...<Widget>[
                        const SizedBox(height: 16),
                        _InlineError(message: item.lastError!),
                      ],
                      if (item.tasks.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _expandedTasks = !_expandedTasks;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Tasks (${item.tasks.length})',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _expandedTasks
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_expandedTasks)
                          ...item.tasks.map((task) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.name,
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (task
                                              .scheduleLabel
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task.scheduleLabel,
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: controller != null
                                          ? () => controller.runTaskNow(task.id)
                                          : null,
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Run now'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                      if (footer != null) ...<Widget>[
                        const SizedBox(height: 18),
                        footer,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AiWidgetInfoPane extends StatelessWidget {
  const _AiWidgetInfoPane({
    required this.item,
    required this.snapshot,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.metric,
    required this.rows,
    required this.chips,
    required this.cadenceLabel,
    required this.updatedLabel,
  });

  final AiWidgetItem item;
  final WidgetSnapshotItem? snapshot;
  final Color accent;
  final String title;
  final String subtitle;
  final String body;
  final String metric;
  final List<Map<String, dynamic>> rows;
  final List<String> chips;
  final String cadenceLabel;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final kicker = _widgetSanitizedText(snapshot?.kicker ?? '');
    final metricLabel = _widgetSanitizedText(snapshot?.metricLabel ?? '');
    final secondaryMetric = _widgetSanitizedText(
      snapshot?.secondaryMetric ?? '',
    );
    final secondaryLabel = _widgetSanitizedText(snapshot?.secondaryLabel ?? '');
    final tertiaryMetric = _widgetSanitizedText(snapshot?.tertiaryMetric ?? '');
    final tertiaryLabel = _widgetSanitizedText(snapshot?.tertiaryLabel ?? '');
    final progress = snapshot?.progress;
    final progressValue = _widgetProgressFraction(progress);
    final hasUsefulRows = rows.any(
      (row) =>
          (row['label']?.toString() ?? '').trim().isNotEmpty ||
          (row['value']?.toString() ?? '').trim().isNotEmpty,
    );
    final hasSnapshotData =
        metric.trim().isNotEmpty ||
        secondaryMetric.isNotEmpty ||
        tertiaryMetric.isNotEmpty ||
        hasUsefulRows ||
        chips.isNotEmpty ||
        body.trim().isNotEmpty;
    final displayName = _widgetDisplayName(item.name);
    final titleIsDuplicate =
        _widgetSanitizedText(title).toLowerCase() == displayName.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (kicker.isNotEmpty) ...<Widget>[
          Text(
            kicker.toUpperCase(),
            style: TextStyle(
              color: accent.withValues(alpha: 0.94),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.08,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!titleIsDuplicate)
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: _textSecondary, height: 1.35),
          ),
        ],
        const SizedBox(height: 18),
        if (metric.trim().isNotEmpty) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric,
                  style: _displayTitleStyle(
                    42,
                  ).copyWith(color: accent, letterSpacing: -1.35),
                ),
                if (metricLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    metricLabel,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (progress != null && progressValue != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _WidgetProgressBar(
                    accent: accent,
                    value: progressValue,
                    label: _widgetProgressLabel(progress),
                  ),
                ],
                if (secondaryMetric.isNotEmpty ||
                    tertiaryMetric.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      if (secondaryMetric.isNotEmpty)
                        _WidgetSupportingMetricCard(
                          label: secondaryLabel.ifEmpty('Secondary'),
                          value: secondaryMetric,
                          accent: accent,
                        ),
                      if (tertiaryMetric.isNotEmpty)
                        _WidgetSupportingMetricCard(
                          label: tertiaryLabel.ifEmpty('Detail'),
                          value: tertiaryMetric,
                          accent: accent,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else if (!hasSnapshotData) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Waiting for the first refresh. Once live data arrives, this widget will lead with the key number and keep the rest compact.',
              style: TextStyle(
                color: _textSecondary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
        if (body.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          MarkdownBody(
            data: body,
            selectable: false,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: TextStyle(color: _textPrimary, height: 1.5, fontSize: 15),
                  h1: TextStyle(
                    color: _textPrimary,
                    height: 1.3,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  h2: TextStyle(
                    color: _textPrimary,
                    height: 1.3,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: TextStyle(
                    color: _textPrimary,
                    height: 1.3,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  listBullet: TextStyle(color: _textSecondary, height: 1.4),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
          ),
        ],
        if (hasUsefulRows) ...<Widget>[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: rows.take(3).map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _widgetSanitizedText(
                            row['label']?.toString() ?? '',
                            fallback: 'Detail',
                          ),
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _widgetSanitizedText(row['value']?.toString() ?? ''),
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (chips.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.take(3).map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _WidgetMetricBlock(label: 'Refreshes', value: cadenceLabel),
            _WidgetMetricBlock(label: 'Last update', value: updatedLabel),
            _WidgetMetricBlock(
              label: 'Status',
              value: item.enabled ? 'Live' : 'Paused',
              accent: item.enabled ? _success : _textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _AiWidgetAndroidPreview extends StatelessWidget {
  const _AiWidgetAndroidPreview({
    required this.item,
    required this.accent,
    required this.icon,
    this.snapshot,
    this.compact = false,
  });

  final AiWidgetItem item;
  final Color accent;
  final IconData icon;
  final WidgetSnapshotItem? snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final activeSnapshot = snapshot ?? item.latestSnapshot;
    final displayName = _widgetDisplayName(item.name);
    final title = _widgetPrimaryTitle(item, activeSnapshot);
    final subtitle = _widgetSecondaryTitle(item, activeSnapshot);
    final body = _widgetSummaryText(item, activeSnapshot);
    final metric = _widgetSanitizedText(activeSnapshot?.metric ?? '');
    final metricLabel = _widgetSanitizedText(activeSnapshot?.metricLabel ?? '');
    final secondaryMetric = _widgetSanitizedText(
      activeSnapshot?.secondaryMetric ?? '',
    );
    final secondaryLabel = _widgetSanitizedText(
      activeSnapshot?.secondaryLabel ?? '',
    );
    final tertiaryMetric = _widgetSanitizedText(
      activeSnapshot?.tertiaryMetric ?? '',
    );
    final tertiaryLabel = _widgetSanitizedText(
      activeSnapshot?.tertiaryLabel ?? '',
    );
    final rows = activeSnapshot?.rows ?? const <Map<String, dynamic>>[];
    final chips = activeSnapshot?.chips ?? const <String>[];
    final progress = activeSnapshot?.progress;
    final previewRatio = _widgetPreviewAspectRatio(item.template);
    final palette = _widgetPreviewPalette(
      item.template,
      accent,
      backgroundToken: activeSnapshot?.backgroundToken ?? '',
      surfaceColor: activeSnapshot?.surfaceColor ?? '',
    );
    return AspectRatio(
      aspectRatio: previewRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 30 : 34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.colors,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.glow,
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: compact ? 26 : 28,
                    height: compact ? 26 : 28,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: compact ? 16 : 17,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: compact ? 18 : 20,
                    color: palette.foreground.withValues(alpha: 0.8),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: compact ? 18 : 20,
                    color: palette.foreground.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (item.template) {
                  'list' => _AiWidgetPreviewList(
                    displayName: displayName,
                    title: title,
                    subtitle: subtitle,
                    rows: rows,
                    chips: chips,
                    accent: palette.accent,
                    palette: palette,
                    compact: compact,
                  ),
                  'summary' => _AiWidgetPreviewSummary(
                    displayName: displayName,
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    metric: metric,
                    metricLabel: metricLabel,
                    chips: chips,
                    palette: palette,
                    compact: compact,
                  ),
                  _ => _AiWidgetPreviewStat(
                    displayName: displayName,
                    title: title,
                    subtitle: subtitle,
                    metric: metric,
                    metricLabel: metricLabel,
                    secondaryMetric: secondaryMetric,
                    secondaryLabel: secondaryLabel,
                    tertiaryMetric: tertiaryMetric,
                    tertiaryLabel: tertiaryLabel,
                    progress: progress,
                    rows: rows,
                    accent: palette.accent,
                    palette: palette,
                    compact: compact,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiWidgetPreviewStat extends StatelessWidget {
  const _AiWidgetPreviewStat({
    required this.displayName,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.secondaryMetric,
    required this.secondaryLabel,
    required this.tertiaryMetric,
    required this.tertiaryLabel,
    required this.progress,
    required this.rows,
    required this.accent,
    required this.palette,
    required this.compact,
  });

  final String displayName;
  final String title;
  final String subtitle;
  final String metric;
  final String metricLabel;
  final String secondaryMetric;
  final String secondaryLabel;
  final String tertiaryMetric;
  final String tertiaryLabel;
  final Map<String, dynamic>? progress;
  final List<Map<String, dynamic>> rows;
  final Color accent;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleIsDuplicate =
        _widgetSanitizedText(title).toLowerCase() == displayName.toLowerCase();
    final values = rows
        .where(
          (row) =>
              _widgetSanitizedText(row['label']?.toString() ?? '').isNotEmpty ||
              _widgetSanitizedText(row['value']?.toString() ?? '').isNotEmpty,
        )
        .take(3)
        .toList(growable: false);
    final hasMetric = metric.trim().isNotEmpty;
    final progressValue = _widgetProgressFraction(progress);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = compact || constraints.maxHeight < 190;
        final showSupportingPills =
            !dense && (secondaryMetric.isNotEmpty || tertiaryMetric.isNotEmpty);
        final showProgressValue = !dense ? progressValue : null;
        final visibleRows = values.take(dense ? 1 : 3).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 11 : (compact ? 12 : 13),
                ),
              ),
            SizedBox(height: dense ? 6 : 8),
            if (!titleIsDuplicate)
              Text(
                title.trim().isNotEmpty ? title : 'Waiting for first update',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontSize: dense ? 15 : (compact ? 16 : 18),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.35,
                ),
              ),
            SizedBox(height: dense ? 8 : 10),
            Text(
              hasMetric ? metric : 'Waiting for first update',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.foreground,
                fontSize: dense ? 25 : (compact ? 30 : 34),
                height: 0.96,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.1,
              ),
            ),
            if (metricLabel.trim().isNotEmpty) ...<Widget>[
              SizedBox(height: dense ? 4 : 6),
              Text(
                metricLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 10 : (compact ? 11 : 12),
                ),
              ),
            ],
            if (showSupportingPills) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (secondaryMetric.isNotEmpty)
                    _WidgetPreviewDataPill(
                      label: secondaryLabel.ifEmpty('Secondary'),
                      value: secondaryMetric,
                      palette: palette,
                    ),
                  if (tertiaryMetric.isNotEmpty)
                    _WidgetPreviewDataPill(
                      label: tertiaryLabel.ifEmpty('Detail'),
                      value: tertiaryMetric,
                      palette: palette,
                    ),
                ],
              ),
            ],
            if (showProgressValue != null) ...<Widget>[
              const SizedBox(height: 12),
              _WidgetPreviewProgress(
                value: showProgressValue,
                label: _widgetProgressLabel(progress),
                palette: palette,
              ),
            ],
            if (visibleRows.isNotEmpty) ...<Widget>[
              SizedBox(height: dense ? 10 : 14),
              ...visibleRows.map(
                (row) => Padding(
                  padding: EdgeInsets.only(bottom: dense ? 6 : 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _widgetSanitizedText(row['label']?.toString() ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: dense ? 10 : (compact ? 11 : 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _widgetSanitizedText(row['value']?.toString() ?? ''),
                        style: TextStyle(
                          color: palette.foreground,
                          fontSize: dense ? 11 : (compact ? 12 : 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...<Widget>[
              const Spacer(),
              Text(
                'Waiting for first update',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 11 : (compact ? 12 : 13),
                ),
              ),
              SizedBox(height: dense ? 8 : 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(dense ? 6 : 8, (index) {
                  final count = dense ? 6 : 8;
                  final factor = (count - index) / count;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: dense ? 7 : (compact ? 8 : 10),
                      height: (dense ? 16 : (compact ? 20 : 26)) * factor + 8,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.62 - (index * 0.05)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AiWidgetPreviewSummary extends StatelessWidget {
  const _AiWidgetPreviewSummary({
    required this.displayName,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.metric,
    required this.metricLabel,
    required this.chips,
    required this.palette,
    required this.compact,
  });

  final String displayName;
  final String title;
  final String subtitle;
  final String body;
  final String metric;
  final String metricLabel;
  final List<String> chips;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topLabel = subtitle.trim().isNotEmpty ? subtitle : 'Summary';
    final headline = title.trim().isNotEmpty
        ? title
        : 'Waiting for first update';
    final headlineIsDuplicate =
        _widgetSanitizedText(headline).toLowerCase() ==
        displayName.toLowerCase();
    final copy = body.trim().isNotEmpty ? body : headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          topLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.muted, fontSize: compact ? 11 : 12),
        ),
        const SizedBox(height: 10),
        if (!headlineIsDuplicate)
          Text(
            headline,
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontSize: compact ? 20 : 24,
              height: 1.12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
            ),
          ),
        if (copy != headline) ...<Widget>[
          const SizedBox(height: 10),
          MarkdownBody(
            data: copy,
            selectable: false,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.86),
                    fontSize: compact ? 13 : 14,
                    height: 1.34,
                  ),
                  h1: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.92),
                    fontSize: compact ? 16 : 17,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                  h2: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.92),
                    fontSize: compact ? 15 : 16,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.92),
                    fontSize: compact ? 14 : 15,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                  listBullet: TextStyle(
                    color: palette.muted,
                    fontSize: compact ? 12 : 13,
                    height: 1.28,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: palette.chip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
          ),
        ],
        if (metric.isNotEmpty) ...<Widget>[
          const Spacer(),
          _WidgetPreviewDataPill(
            label: metricLabel.ifEmpty('Now'),
            value: metric,
            palette: palette,
          ),
          const SizedBox(height: 10),
        ] else if (chips.isNotEmpty) ...<Widget>[const Spacer()],
        if (chips.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.take(2).map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.chip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.94),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _AiWidgetPreviewList extends StatelessWidget {
  const _AiWidgetPreviewList({
    required this.displayName,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.chips,
    required this.accent,
    required this.palette,
    required this.compact,
  });

  final String displayName;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> rows;
  final List<String> chips;
  final Color accent;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleIsDuplicate =
        _widgetSanitizedText(title).toLowerCase() == displayName.toLowerCase();
    final entries = rows.isEmpty
        ? chips
              .map((chip) => <String, dynamic>{'label': chip, 'value': ''})
              .toList(growable: false)
        : rows.take(4).toList(growable: false);
    if (entries.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Waiting for items',
          style: TextStyle(color: palette.muted, fontSize: compact ? 13 : 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (subtitle.trim().isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.muted, fontSize: compact ? 11 : 12),
          ),
        if (!titleIsDuplicate && title.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...entries.map((row) {
          final label = _widgetSanitizedText(
            row['label']?.toString() ?? '',
            fallback: 'Item',
          );
          final value = _widgetSanitizedText(row['value']?.toString() ?? '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 18 : 20,
                  height: compact ? 18 : 20,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: compact ? 12 : 14,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (value.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _WidgetSupportingMetricCard extends StatelessWidget {
  const _WidgetSupportingMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetProgressBar extends StatelessWidget {
  const _WidgetProgressBar({
    required this.accent,
    required this.value,
    required this.label,
  });

  final Color accent;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _WidgetPreviewDataPill extends StatelessWidget {
  const _WidgetPreviewDataPill({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _WidgetPreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.foreground.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreviewProgress extends StatelessWidget {
  const _WidgetPreviewProgress({
    required this.value,
    required this.label,
    required this.palette,
  });

  final double value;
  final String label;
  final _WidgetPreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _WidgetMetricBlock extends StatelessWidget {
  const _WidgetMetricBlock({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent ?? _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreviewPalette {
  const _WidgetPreviewPalette({
    required this.colors,
    required this.accent,
    required this.foreground,
    required this.muted,
    required this.chip,
    required this.glow,
  });

  final List<Color> colors;
  final Color accent;
  final Color foreground;
  final Color muted;
  final Color chip;
  final Color glow;
}

Color _widgetAccentColor(String token, {String surfaceColor = ''}) {
  final surfaceOverride = _widgetColorFromHex(surfaceColor);
  if (surfaceOverride != null) {
    return Color.lerp(surfaceOverride, Colors.white, 0.16)!;
  }
  switch (token.trim().toLowerCase()) {
    case 'warning':
    case 'sun':
    case 'sunny':
    case 'weather':
      return _warning;
    case 'success':
    case 'health':
    case 'growth':
    case 'battery':
    case 'electric':
      return _success;
    case 'alert':
    case 'error':
    case 'storm':
      return _danger;
    case 'sky':
    case 'ocean':
    case 'summary':
    case 'rain':
    case 'cloud':
      return _accentAlt;
    case 'night':
      return const Color(0xFFB7C9FF);
    default:
      return _accent;
  }
}

IconData _widgetIconData(String token) {
  switch (token.trim().toLowerCase()) {
    case 'weather':
    case 'sun':
    case 'sunny':
      return Icons.wb_sunny_outlined;
    case 'rain':
    case 'storm':
      return Icons.thunderstorm_outlined;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'vehicle':
    case 'car':
      return Icons.directions_car_outlined;
    case 'battery':
    case 'electric':
      return Icons.battery_charging_full_rounded;
    case 'list':
    case 'agenda':
      return Icons.view_list_outlined;
    case 'health':
      return Icons.favorite_outline;
    case 'summary':
      return Icons.notes_outlined;
    default:
      return Icons.dashboard_customize_outlined;
  }
}

String _manualRunButtonLabel(String label, int remainingSeconds) {
  if (remainingSeconds <= 0) {
    return label;
  }
  return '$label (${remainingSeconds}s)';
}

String _widgetSanitizedText(String value, {String fallback = ''}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return fallback;
  }
  return normalized;
}

String _widgetDisplayName(String raw) {
  final normalized = raw
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return 'AI Widget';
  }
  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length <= 2 && part.toUpperCase() == part) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _widgetPrimaryTitle(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final snapshotTitle = _widgetSanitizedText(snapshot?.title ?? '');
  if (snapshotTitle.isNotEmpty) {
    return snapshotTitle;
  }
  return _widgetDisplayName(item.name);
}

String _widgetSecondaryTitle(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final kicker = _widgetSanitizedText(snapshot?.kicker ?? '');
  if (kicker.isNotEmpty) {
    return kicker;
  }
  final subtitle = _widgetSanitizedText(snapshot?.subtitle ?? '');
  if (subtitle.isNotEmpty) {
    return subtitle;
  }
  final metricLabel = _widgetSanitizedText(snapshot?.metricLabel ?? '');
  if (metricLabel.isNotEmpty) {
    return metricLabel;
  }
  if (snapshot != null) {
    return _widgetDisplayName(item.name);
  }
  return 'Waiting for the first update';
}

String _widgetSummaryText(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final body = _widgetSanitizedText(snapshot?.body ?? '');
  if (body.isNotEmpty) {
    return body;
  }
  final supportingFacts = <String>[
    _widgetLabeledValue(
      snapshot?.secondaryLabel ?? '',
      snapshot?.secondaryMetric ?? '',
    ),
    _widgetLabeledValue(
      snapshot?.tertiaryLabel ?? '',
      snapshot?.tertiaryMetric ?? '',
    ),
  ].where((entry) => entry.isNotEmpty).toList(growable: false);
  if (supportingFacts.isNotEmpty) {
    return supportingFacts.join(' • ');
  }
  final rowSummary = snapshot?.rows
      .map(
        (row) => _widgetLabeledValue(
          row['label']?.toString() ?? '',
          row['value']?.toString() ?? '',
        ),
      )
      .where((entry) => entry.isNotEmpty)
      .take(2)
      .join(' • ');
  if (rowSummary != null && rowSummary.isNotEmpty) {
    return rowSummary;
  }
  final description = _widgetSanitizedText(
    item.definition['description']?.toString() ?? '',
  );
  if (description.isNotEmpty) {
    return description;
  }
  final prompt = _widgetSanitizedText(item.prompt);
  if (prompt.isNotEmpty) {
    return prompt;
  }
  return snapshot == null
      ? 'Waiting for the first update.'
      : 'Opens the latest widget snapshot everywhere you use NeoAgent.';
}

String _widgetCadenceLabel(String cron) {
  final normalized = cron.trim();
  final parts = normalized.split(RegExp(r'\s+'));
  if (parts.length != 5) {
    return normalized.isEmpty ? 'Refreshes on schedule' : normalized;
  }
  final minute = parts[0];
  final hour = parts[1];
  final dayOfWeek = parts[4];
  if (minute == '0' && hour == '*' && parts[2] == '*' && parts[3] == '*') {
    return 'Hourly';
  }
  if (minute == '0' &&
      hour.startsWith('*/') &&
      parts[2] == '*' &&
      parts[3] == '*') {
    final interval = int.tryParse(hour.substring(2));
    if (interval != null && interval > 1) {
      return 'Every $interval hours';
    }
  }
  if (minute != '*' &&
      hour != '*' &&
      parts[2] == '*' &&
      parts[3] == '*' &&
      dayOfWeek == '*') {
    final minuteValue = int.tryParse(minute);
    final hourValue = int.tryParse(hour);
    if (minuteValue != null && hourValue != null) {
      final localizations = WidgetsBinding.instance.platformDispatcher.locale;
      final formattedMinute = minuteValue.toString().padLeft(2, '0');
      final formattedHour = hourValue.toString().padLeft(2, '0');
      if (localizations.languageCode.toLowerCase() == 'en') {
        return 'Daily at $formattedHour:$formattedMinute';
      }
      return 'Daily at $formattedHour:$formattedMinute';
    }
  }
  return normalized;
}

double _widgetPreviewAspectRatio(String template) {
  switch (template.trim().toLowerCase()) {
    case 'summary':
      return 1.9;
    case 'list':
      return 1.08;
    default:
      return 1.18;
  }
}

String _widgetLabeledValue(String label, String value) {
  final safeLabel = _widgetSanitizedText(label);
  final safeValue = _widgetSanitizedText(value);
  if (safeLabel.isEmpty) return safeValue;
  if (safeValue.isEmpty) return safeLabel;
  return '$safeLabel $safeValue';
}

Color? _widgetColorFromHex(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
    return null;
  }
  final value = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return Color(value);
}

Color _widgetBackgroundSeed(String token, Color accent) {
  switch (token.trim().toLowerCase()) {
    case 'sun':
    case 'sunny':
      return const Color(0xFFD59B4E);
    case 'rain':
      return const Color(0xFF5274A7);
    case 'storm':
      return const Color(0xFF50597A);
    case 'cloud':
      return const Color(0xFF71809A);
    case 'night':
      return const Color(0xFF42507B);
    case 'electric':
    case 'battery':
      return const Color(0xFF37C990);
    case 'vehicle':
      return const Color(0xFF5B6E88);
    default:
      return accent;
  }
}

double? _widgetProgressFraction(Map<String, dynamic>? progress) {
  if (progress == null) {
    return null;
  }
  final value = double.tryParse(progress['value']?.toString() ?? '');
  final max = double.tryParse(progress['max']?.toString() ?? '');
  if (value == null || max == null || max <= 0) {
    return null;
  }
  return (value / max).clamp(0.0, 1.0);
}

String _widgetProgressLabel(Map<String, dynamic>? progress) {
  if (progress == null) {
    return '';
  }
  final explicit = _widgetSanitizedText(progress['label']?.toString() ?? '');
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final value = progress['value']?.toString() ?? '';
  final max = progress['max']?.toString() ?? '';
  if (value.isNotEmpty && max.isNotEmpty) {
    return '$value / $max';
  }
  return '';
}

_WidgetPreviewPalette _widgetPreviewPalette(
  String template,
  Color accent, {
  String backgroundToken = '',
  String surfaceColor = '',
}) {
  final surfaceOverride = _widgetColorFromHex(surfaceColor);
  final seed =
      surfaceOverride ?? _widgetBackgroundSeed(backgroundToken, accent);
  final accentColor = Color.lerp(seed, Colors.white, 0.18)!;
  final start = switch (template.trim().toLowerCase()) {
    'summary' => Color.lerp(seed, const Color(0xFF101B28), 0.28)!,
    'list' => Color.lerp(seed, const Color(0xFF162130), 0.44)!,
    _ => Color.lerp(seed, const Color(0xFF121A25), 0.34)!,
  };
  final end = switch (template.trim().toLowerCase()) {
    'summary' => Color.lerp(seed, const Color(0xFF081018), 0.74)!,
    'list' => Color.lerp(seed, const Color(0xFF0D141F), 0.78)!,
    _ => Color.lerp(seed, const Color(0xFF0B121C), 0.8)!,
  };
  return _WidgetPreviewPalette(
    colors: <Color>[start, end],
    accent: accentColor,
    foreground: Colors.white,
    muted: Colors.white.withValues(alpha: 0.72),
    chip: Colors.white.withValues(alpha: 0.11),
    glow: accentColor.withValues(alpha: 0.18),
  );
}

class _TaskTriggerOption {
  const _TaskTriggerOption({
    required this.type,
    required this.section,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String type;
  final String section;
  final String label;
  final String description;
  final IconData icon;
}

const List<_TaskTriggerOption> _taskTriggerOptions = <_TaskTriggerOption>[
  _TaskTriggerOption(
    type: 'manual',
    section: 'On Demand',
    label: 'Manual Trigger',
    description: 'Runs only when you press Run Now.',
    icon: Icons.play_circle_outline_rounded,
  ),
  _TaskTriggerOption(
    type: 'schedule',
    section: 'Time',
    label: 'Schedule',
    description: 'Cron-based recurring runs and one-time timed execution.',
    icon: Icons.schedule_rounded,
  ),
  _TaskTriggerOption(
    type: 'gmail_message_received',
    section: 'Email',
    label: 'Gmail Message Received',
    description: 'Run when a matching Gmail message arrives.',
    icon: Icons.mail_rounded,
  ),
  _TaskTriggerOption(
    type: 'outlook_email_received',
    section: 'Email',
    label: 'Outlook Email Received',
    description: 'Run when a matching Outlook email arrives.',
    icon: Icons.markunread_rounded,
  ),
  _TaskTriggerOption(
    type: 'slack_message_received',
    section: 'Messaging',
    label: 'Slack Message Received',
    description: 'Run when a Slack message matches the selected scope.',
    icon: Icons.forum_rounded,
  ),
  _TaskTriggerOption(
    type: 'teams_message_received',
    section: 'Messaging',
    label: 'Teams Message Received',
    description: 'Run when a Teams chat message matches the selected scope.',
    icon: Icons.groups_rounded,
  ),
  _TaskTriggerOption(
    type: 'weather_event',
    section: 'Environment',
    label: 'Weather Event',
    description:
        'Run when configured weather events are forecast for a location.',
    icon: Icons.cloudy_snowing,
  ),
  _TaskTriggerOption(
    type: 'whatsapp_personal_message_received',
    section: 'Messaging',
    label: 'WhatsApp Personal Message Received',
    description: 'Run on inbound personal WhatsApp messages.',
    icon: Icons.chat_bubble_rounded,
  ),
];

_TaskTriggerOption _taskTriggerOptionForType(String type) {
  return _taskTriggerOptions.firstWhere(
    (option) => option.type == type,
    orElse: () => _taskTriggerOptions.first,
  );
}

Future<String?> _pickTaskTriggerType(
  BuildContext context,
  String selectedType,
) {
  final optionsBySection = <String, List<_TaskTriggerOption>>{};
  for (final option in _taskTriggerOptions) {
    optionsBySection
        .putIfAbsent(option.section, () => <_TaskTriggerOption>[])
        .add(option);
  }

  return showDialog<String>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: _bgCard,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Select Trigger',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how this task should start. Manual runs only on Run Now. Schedule is time-based. Integration triggers fire from connected official apps.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: optionsBySection.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...entry.value.map((option) {
                              final isSelected = option.type == selectedType;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      Navigator.of(context).pop(option.type),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? _accent : _border,
                                        width: isSelected ? 1.6 : 1,
                                      ),
                                      gradient: isSelected
                                          ? LinearGradient(
                                              colors: <Color>[
                                                _accent.withValues(alpha: 0.18),
                                                _accent.withValues(alpha: 0.05),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : _bgCard.withValues(alpha: 0.72),
                                      boxShadow: isSelected
                                          ? <BoxShadow>[
                                              BoxShadow(
                                                color: _accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                                blurRadius: 24,
                                                offset: const Offset(0, 10),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _accent.withValues(
                                                    alpha: 0.16,
                                                  )
                                                : _bgCard,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            option.icon,
                                            color: isSelected
                                                ? _accent
                                                : _textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                option.label,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                option.description,
                                                style: TextStyle(
                                                  color: _textSecondary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.arrow_forward_rounded,
                                          color: isSelected
                                              ? _accent
                                              : _textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  String? _agentFilterId;

  NeoAgentController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant TasksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_agentFilterId == null) return;
    final stillExists = controller.agentProfiles.any(
      (agent) => agent.id == _agentFilterId,
    );
    if (!stillExists) {
      _agentFilterId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _agentFilterId == null
        ? controller.taskItems
        : controller.taskItems
              .where((task) => task.agentId == _agentFilterId)
              .toList();
    final automationTasks = filteredTasks
        .where((task) => !task.isWidgetRefresh)
        .toList();
    final widgetTasks = filteredTasks
        .where((task) => task.isWidgetRefresh)
        .toList();
    final selectedAgentLabel = controller.agentLabelFor(_agentFilterId);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Tasks',
          subtitle:
              'Premium automation with schedule and integration triggers.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.openWidgetCreateFlow,
                icon: Icon(Icons.dashboard_customize_outlined),
                label: Text('Create Widget'),
              ),
              FilledButton.icon(
                onPressed: () => _openTaskEditor(
                  context,
                  defaultAgentId: _agentFilterId ?? controller.selectedAgentId,
                ),
                icon: Icon(Icons.add),
                label: Text('Add Task'),
              ),
            ],
          ),
        ),
        if (controller.agentProfiles.isNotEmpty) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Assigned agent',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(
                          'All agents (${controller.taskItems.length})',
                        ),
                        selected: _agentFilterId == null,
                        onSelected: (_) =>
                            setState(() => _agentFilterId = null),
                      ),
                      ...controller.agentProfiles.map((agent) {
                        final count = controller.taskItems
                            .where((task) => task.agentId == agent.id)
                            .length;
                        return ChoiceChip(
                          label: Text('${agent.displayName} ($count)'),
                          selected: _agentFilterId == agent.id,
                          onSelected: (_) =>
                              setState(() => _agentFilterId = agent.id),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (controller.taskItems.isEmpty)
          const _EmptyCard(
            title: 'No tasks yet',
            subtitle: 'Create a task with a trigger to automate regular work.',
          )
        else if (filteredTasks.isEmpty)
          _EmptyCard(
            title: 'No tasks for $selectedAgentLabel',
            subtitle: 'Create a task while this agent is selected.',
          )
        else ...<Widget>[
          if (automationTasks.isNotEmpty) ...<Widget>[
            Text('Tasks', style: _sectionEyebrowStyle()),
            const SizedBox(height: 10),
            ...automationTasks.map(_buildTaskCard),
          ],
          if (widgetTasks.isNotEmpty) ...<Widget>[
            if (automationTasks.isNotEmpty) const SizedBox(height: 18),
            Text('Managed Widget Tasks', style: _sectionEyebrowStyle()),
            const SizedBox(height: 10),
            ...widgetTasks.map(_buildWidgetTaskCard),
          ],
        ],
      ],
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    final remaining = controller.taskRunCooldownSeconds(task.id);
    return Padding(
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
                      task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: task.enabled ? 'Active' : 'Paused',
                    color: task.enabled ? _success : _textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.scheduleLabel,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
              ),
              if (task.hasModelOverride) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Model: ${_modelLabelForValue(task.model, controller.supportedModels)}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Assigned agent: ${controller.agentLabelFor(task.agentId)}',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 8),
              Text(task.prompt, style: TextStyle(color: _textPrimary)),
              if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last run: ${task.lastRunLabel}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => _openTaskEditor(context, task: task),
                    child: Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: () => controller.toggleTask(task),
                    child: Text(task.enabled ? 'Pause' : 'Enable'),
                  ),
                  FilledButton(
                    onPressed: remaining > 0
                        ? null
                        : () => controller.runTaskNow(task.id),
                    child: Text(_manualRunButtonLabel('Run Now', remaining)),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmDelete(
                      context,
                      title: 'Delete task?',
                      message: 'This will remove "${task.name}".',
                      onConfirm: () => controller.deleteTask(task.id),
                    ),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetTaskCard(TaskItem task) {
    AiWidgetItem? linkedWidget;
    for (final item in controller.widgets) {
      if (item.id == task.widgetId) {
        linkedWidget = item;
        break;
      }
    }
    final remaining = linkedWidget == null
        ? controller.taskRunCooldownSeconds(task.id)
        : controller.widgetRunCooldownSeconds(linkedWidget.id);
    return Padding(
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
                      linkedWidget?.name ?? task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: task.enabled ? 'Active' : 'Paused',
                    color: task.enabled ? _success : _textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.scheduleLabel,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assigned agent: ${controller.agentLabelFor(task.agentId)}',
                style: TextStyle(color: _textSecondary),
              ),
              if (linkedWidget != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${linkedWidget.template} · ${linkedWidget.layoutVariant}',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  linkedWidget.prompt,
                  style: TextStyle(color: _textPrimary),
                ),
              ],
              if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last run: ${task.lastRunLabel}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => controller.openWidgetEditFlow(linkedWidget!),
                    child: Text('Edit With AI'),
                  ),
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => controller.toggleWidgetEnabled(linkedWidget!),
                    child: Text(task.enabled ? 'Pause' : 'Enable'),
                  ),
                  FilledButton(
                    onPressed: remaining > 0
                        ? null
                        : (linkedWidget == null
                              ? () => controller.runTaskNow(task.id)
                              : () => controller.refreshWidgetNow(
                                  linkedWidget!.id,
                                )),
                    child: Text(
                      _manualRunButtonLabel('Refresh Now', remaining),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => _confirmDelete(
                            context,
                            title: 'Delete widget?',
                            message:
                                'This will remove "${linkedWidget!.name}" and its refresh job.',
                            onConfirm: () =>
                                controller.deleteWidget(linkedWidget!.id),
                          ),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTaskEditor(
    BuildContext context, {
    TaskItem? task,
    String? defaultAgentId,
  }) async {
    final nameController = TextEditingController(text: task?.name ?? '');
    final triggerType = ValueNotifier<String>(task?.triggerType ?? 'schedule');
    final cronController = TextEditingController(
      text: task?.triggerConfig['cronExpression']?.toString() ?? '*/30 * * * *',
    );
    final runAtController = TextEditingController(
      text: task?.triggerConfig['runAt']?.toString() ?? '',
    );
    final connectionIdController = TextEditingController(
      text: task?.triggerConfig['connectionId']?.toString() ?? '',
    );
    final queryController = TextEditingController(
      text:
          task?.triggerConfig['query']?.toString() ??
          task?.triggerConfig['location']?.toString() ??
          '',
    );
    final weatherEventTypesController = TextEditingController(
      text: (() {
        final raw = task?.triggerConfig['eventTypes'];
        if (raw is List) {
          return raw.map((entry) => entry.toString()).join(', ');
        }
        return task?.triggerConfig['eventTypes']?.toString() ??
            'rain_start, wind_alert';
      })(),
    );
    final channelController = TextEditingController(
      text:
          task?.triggerConfig['channel']?.toString() ??
          task?.triggerConfig['chatId']?.toString() ??
          '',
    );
    final senderController = TextEditingController(
      text: task?.triggerConfig['sender']?.toString() ?? '',
    );
    final promptController = TextEditingController(text: task?.prompt ?? '');
    var enabled = task?.enabled ?? true;
    var unreadOnly = task?.triggerConfig['unreadOnly'] == true;
    var ignoreGroups = task?.triggerConfig['ignoreGroups'] == true;
    var selectedModel = _ensureModelValue(
      task?.model ?? 'auto',
      controller.supportedModels,
      allowAuto: true,
    );
    var selectedAgentId =
        task?.agentId ?? defaultAgentId ?? controller.selectedAgentId;
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
              title: Text(task == null ? 'Add Task' : 'Edit Task'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: triggerType,
                        builder: (context, selectedTriggerType, _) {
                          final option = _taskTriggerOptionForType(
                            selectedTriggerType,
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              final nextType = await _pickTaskTriggerType(
                                context,
                                selectedTriggerType,
                              );
                              if (nextType != null) {
                                triggerType.value = nextType;
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Trigger Type',
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(option.icon, color: _accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          option.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          option.description,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _bgCard.withValues(
                                            alpha: 0.72,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          option.section,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        Icons.unfold_more_rounded,
                                        color: _textSecondary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: triggerType,
                        builder: (context, selectedTriggerType, _) {
                          if (selectedTriggerType == 'manual') {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'This task will only run when you press Run Now.',
                                style: TextStyle(color: _textSecondary),
                              ),
                            );
                          }
                          if (selectedTriggerType == 'schedule') {
                            return Column(
                              children: <Widget>[
                                TextField(
                                  controller: cronController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cron Expression',
                                    helperText:
                                        'Use cron for recurring tasks. Leave Run At empty for recurring schedules.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: runAtController,
                                  decoration: const InputDecoration(
                                    labelText: 'Run At (optional ISO datetime)',
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: <Widget>[
                              TextField(
                                controller: connectionIdController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Official Integration Connection ID',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (selectedTriggerType ==
                                  'weather_event') ...<Widget>[
                                TextField(
                                  controller: queryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Location (city or place)',
                                    helperText: 'Required. Example: Berlin, DE',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: weatherEventTypesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Event Types (comma separated)',
                                    helperText:
                                        'Supported: rain_start, snow_start, wind_alert, temperature_above, temperature_below',
                                  ),
                                ),
                              ],
                              if (selectedTriggerType ==
                                      'gmail_message_received' ||
                                  selectedTriggerType ==
                                      'outlook_email_received') ...<Widget>[
                                TextField(
                                  controller: queryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Query / Filter',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  value: unreadOnly,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Unread Only'),
                                  onChanged: (value) =>
                                      setLocalState(() => unreadOnly = value),
                                ),
                              ],
                              if (selectedTriggerType ==
                                  'outlook_email_received') ...<Widget>[
                                TextField(
                                  controller: channelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Folder ID (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (selectedTriggerType ==
                                      'slack_message_received' ||
                                  selectedTriggerType ==
                                      'teams_message_received' ||
                                  selectedTriggerType ==
                                      'whatsapp_personal_message_received') ...<
                                Widget
                              >[
                                TextField(
                                  controller: channelController,
                                  decoration: InputDecoration(
                                    labelText:
                                        selectedTriggerType ==
                                            'slack_message_received'
                                        ? 'Channel ID'
                                        : 'Chat ID',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: senderController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sender Filter (optional)',
                                  ),
                                ),
                              ],
                              if (selectedTriggerType ==
                                  'whatsapp_personal_message_received') ...<
                                Widget
                              >[
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  value: ignoreGroups,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ignore Groups'),
                                  onChanged: (value) =>
                                      setLocalState(() => ignoreGroups = value),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(labelText: 'Prompt'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model Override',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'auto',
                            child: Text('Auto (default routing)'),
                          ),
                          ...controller.supportedModels.map(
                            (model) => DropdownMenuItem<String>(
                              value: model.id,
                              child: Text(model.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setLocalState(
                          () => selectedModel = value ?? 'auto',
                        ),
                      ),
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
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
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
                    final selectedTriggerType = triggerType.value;
                    final triggerConfig = <String, dynamic>{};
                    if (selectedTriggerType == 'manual') {
                      // Manual trigger uses no trigger-specific config.
                    } else if (selectedTriggerType == 'schedule') {
                      final runAt = runAtController.text.trim();
                      triggerConfig['mode'] = runAt.isEmpty
                          ? 'recurring'
                          : 'one_time';
                      if (runAt.isEmpty) {
                        triggerConfig['cronExpression'] = cronController.text
                            .trim();
                      } else {
                        triggerConfig['runAt'] = runAt;
                      }
                    } else {
                      final parsedConnectionId = int.tryParse(
                        connectionIdController.text.trim(),
                      );
                      if (parsedConnectionId == null ||
                          parsedConnectionId <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Connection ID must be a positive integer.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      triggerConfig['connectionId'] = parsedConnectionId;
                      if (selectedTriggerType == 'weather_event') {
                        if (queryController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Location is required for weather event triggers',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        triggerConfig['location'] = queryController.text.trim();
                        final eventTypes = weatherEventTypesController.text
                            .split(',')
                            .map((entry) => entry.trim())
                            .where((entry) => entry.isNotEmpty)
                            .toList();
                        triggerConfig['eventTypes'] = eventTypes;
                      }
                      if (selectedTriggerType == 'gmail_message_received' ||
                          selectedTriggerType == 'outlook_email_received') {
                        if (queryController.text.trim().isNotEmpty) {
                          triggerConfig['query'] = queryController.text.trim();
                        }
                        triggerConfig['unreadOnly'] = unreadOnly;
                        if (selectedTriggerType == 'outlook_email_received' &&
                            channelController.text.trim().isNotEmpty) {
                          triggerConfig['folderId'] = channelController.text
                              .trim();
                        }
                      }
                      if (selectedTriggerType == 'slack_message_received') {
                        triggerConfig['channel'] = channelController.text
                            .trim();
                      }
                      if (selectedTriggerType == 'teams_message_received' ||
                          selectedTriggerType ==
                              'whatsapp_personal_message_received') {
                        triggerConfig['chatId'] = channelController.text.trim();
                      }
                      if (senderController.text.trim().isNotEmpty) {
                        triggerConfig['sender'] = senderController.text.trim();
                      }
                      if (selectedTriggerType ==
                          'whatsapp_personal_message_received') {
                        triggerConfig['ignoreGroups'] = ignoreGroups;
                      }
                    }
                    await controller.saveTask(
                      id: task?.id,
                      name: nameController.text.trim(),
                      triggerType: selectedTriggerType,
                      triggerConfig: triggerConfig,
                      prompt: promptController.text.trim(),
                      model: selectedModel == 'auto' ? null : selectedModel,
                      enabled: enabled,
                      agentId: selectedAgentId,
                    );
                    if (context.mounted) {
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
}
