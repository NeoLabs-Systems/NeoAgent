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
        'computerState': controller.computerRuntime['state'],
        'teachState': controller.teachRuntime['status'],
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
                            fontFamily: GoogleFonts.geistMono().fontFamily,
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

  // Installed tab search & filter state
  String _installedQuery = '';
  String _installedStatusFilter =
      'all'; // 'all' | 'active' | 'draft' | 'disabled'
  String _installedSourceFilter =
      'all'; // 'all' | 'built-in' | 'learned' | 'user' | 'store'
  late final TextEditingController _installedSearchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _installedSearchController = TextEditingController();
    _installedSearchController.addListener(() {
      setState(() {
        _installedQuery = _installedSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _installedSearchController.dispose();
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

    final filteredSkills = controller.skills.where((skill) {
      final q = _installedQuery;
      if (q.isNotEmpty &&
          !skill.name.toLowerCase().contains(q) &&
          !skill.description.toLowerCase().contains(q)) {
        return false;
      }
      if (_installedStatusFilter != 'all') {
        if (_installedStatusFilter == 'active' &&
            (!skill.enabled || skill.draft)) {
          return false;
        }
        if (_installedStatusFilter == 'draft' && !skill.draft) {
          return false;
        }
        if (_installedStatusFilter == 'disabled' && skill.enabled) {
          return false;
        }
      }
      if (_installedSourceFilter != 'all' &&
          skill.source != _installedSourceFilter) {
        return false;
      }
      return true;
    }).toList();

    final statusFilters = <String>['all', 'active', 'draft', 'disabled'];
    final sourceFilters = <String>[
      'all',
      'built-in',
      'learned',
      'user',
      'store',
    ];

    return Card(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _installedSearchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name or description',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _installedSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _installedSearchController.clear();
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
                    itemCount: statusFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = statusFilters[index];
                      final selected = filter == _installedStatusFilter;
                      return FilterChip(
                        selected: selected,
                        label: Text(
                          filter == 'all'
                              ? 'All'
                              : filter[0].toUpperCase() + filter.substring(1),
                        ),
                        selectedColor: _accentMuted,
                        checkmarkColor: _accent,
                        backgroundColor: _bgSecondary,
                        side: BorderSide(color: _border),
                        onSelected: (_) =>
                            setState(() => _installedStatusFilter = filter),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sourceFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = sourceFilters[index];
                      final selected = filter == _installedSourceFilter;
                      return FilterChip(
                        selected: selected,
                        label: Text(filter == 'all' ? 'All' : filter),
                        selectedColor: _accentMuted,
                        checkmarkColor: _accent,
                        backgroundColor: _bgSecondary,
                        side: BorderSide(color: _border),
                        onSelected: (_) =>
                            setState(() => _installedSourceFilter = filter),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${filteredSkills.length} skill${filteredSkills.length == 1 ? '' : 's'}',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (filteredSkills.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No skills match your filters',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: filteredSkills.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final skill = filteredSkills[index];
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                        onPressed: () => _openSkillEditor(
                                          context,
                                          skill.name,
                                        ),
                                        child: Text('Open'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _confirmDeleteSkill(
                                          context,
                                          skill.name,
                                        ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          skill.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          skill.description.ifEmpty(
                                            'No description',
                                          ),
                                          style: TextStyle(
                                            color: _textSecondary,
                                          ),
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
                                        onPressed: () => _openSkillEditor(
                                          context,
                                          skill.name,
                                        ),
                                        child: Text('Open'),
                                      ),
                                      const SizedBox(height: 6),
                                      TextButton.icon(
                                        onPressed: () => _confirmDeleteSkill(
                                          context,
                                          skill.name,
                                        ),
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
            ),
        ],
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

class _MemoryPanelState extends State<MemoryPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TextEditingController _llmPromptController;
  late final TextEditingController _llmImportController;
  late final TabController _tabController;
  final Set<String> _selectedMemoryIds = <String>{};
  String? _entityFilter;
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _llmPromptController.dispose();
    _llmImportController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLlmPrompt(NeoAgentController controller) async {
    if (_llmPromptLoading) return;
    setState(() => _llmPromptLoading = true);
    try {
      final prompt = await controller.fetchMemoryTransferPrompt();
      if (!mounted) return;
      setState(() => _llmPromptController.text = prompt);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate prompt: $error')),
      );
    } finally {
      if (mounted) setState(() => _llmPromptLoading = false);
    }
  }

  Future<void> _copyLlmPrompt() async {
    final prompt = _llmPromptController.text.trim();
    if (prompt.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prompt copied.')));
  }

  Future<void> _importLlmMemories(NeoAgentController controller) async {
    if (_llmImporting) return;
    final text = _llmImportController.text.trim();
    if (text.isEmpty) return;
    final confirmImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        final applyTargets = <String>[
          if (_llmApplyBehaviorNotes) 'behavior notes',
          if (_llmApplyCoreMemory) 'core memory',
          'memories',
        ];
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Import memory transfer?'),
          content: Text(
            'This will import the response into ${applyTargets.join(', ')}.',
          ),
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
    if (confirmImport != true) return;
    setState(() => _llmImporting = true);
    try {
      final result = await controller.importMemoryTransfer(
        text,
        applyBehaviorNotes: _llmApplyBehaviorNotes,
        applyCoreMemory: _llmApplyCoreMemory,
      );
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    } finally {
      if (mounted) setState(() => _llmImporting = false);
    }
  }

  List<MemoryItem> get _visibleMemories {
    final controller = widget.controller;
    final base = controller.memoryRecallResults.isNotEmpty
        ? controller.memoryRecallResults
        : controller.memories;
    if (_entityFilter == null) return base;
    return base
        .where((m) => m.entities.any((e) => e.name == _entityFilter))
        .toList();
  }

  List<String> get _selectedVisibleMemoryIds {
    final visibleIds = _visibleMemories.map((m) => m.id).toSet();
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
    if (_selectedMemoryIds.isEmpty) return;
    setState(() => _selectedMemoryIds.clear());
  }

  void _selectAllVisibleMemories(List<MemoryItem> memories) {
    if (memories.isEmpty) return;
    setState(() {
      _selectedMemoryIds.addAll(memories.map((m) => m.id));
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
    setState(() => _entityFilter = null);
    controller.clearMemorySearch();
  }

  Future<void> _deleteSingleMemory(
    NeoAgentController controller,
    String id,
  ) async {
    await controller.deleteMemory(id);
    if (!mounted) return;
    setState(() => _selectedMemoryIds.remove(id));
  }

  Future<void> _runBulkMemoryAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(List<String> ids) onConfirm,
  }) async {
    final ids = _selectedVisibleMemoryIds;
    if (ids.isEmpty || _bulkActionInFlight) return;
    await _confirmDelete(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: () async {
        setState(() => _bulkActionInFlight = true);
        try {
          await onConfirm(ids);
          if (!mounted) return;
          setState(() => _selectedMemoryIds.removeAll(ids));
        } finally {
          if (mounted) setState(() => _bulkActionInFlight = false);
        }
      },
    );
  }

  void _onEntityTapped(String entityName) {
    setState(() {
      _entityFilter = _entityFilter == entityName ? null : entityName;
      _tabController.animateTo(0);
    });
  }

  void _openRetrievalInspector(
    BuildContext context,
    NeoAgentController controller,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RetrievalInspectorView(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final stats = controller.memoryOverview.stats;
    final memoriesToShow = _visibleMemories;
    final selectedIds = _selectedVisibleMemoryIds.toSet();
    final selectedCount = selectedIds.length;
    final allVisibleSelected =
        memoriesToShow.isNotEmpty &&
        memoriesToShow.every((m) => selectedIds.contains(m.id));
    final showingSearchResults = controller.memoryRecallResults.isNotEmpty;
    final compact = MediaQuery.sizeOf(context).width < 760;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Memory',
          subtitle: 'Long-term recall, structured facts, and knowledge graph.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _openRetrievalInspector(context, controller),
                icon: Icon(Icons.bug_report_outlined),
                label: Text('Inspect'),
              ),
              FilledButton.icon(
                onPressed: () => _openMemoryCreator(context, controller),
                icon: Icon(Icons.add),
                label: Text('Add Memory'),
              ),
            ],
          ),
        ),

        // --- Stats bar ---
        _EntranceMotion(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  _MemoryConfidenceGauge(confidence: stats.averageConfidence),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MemoryStatChip(
                          label: '${stats.active}',
                          caption: 'Active',
                          icon: Icons.memory_outlined,
                        ),
                        _MemoryStatChip(
                          label: '${stats.facts}',
                          caption: 'Facts',
                          icon: Icons.fact_check_outlined,
                        ),
                        _MemoryStatChip(
                          label: '${stats.entities}',
                          caption: 'Entities',
                          icon: Icons.hub_outlined,
                        ),
                        _MemoryStatChip(
                          label: '${stats.knowledgeViews}',
                          caption: 'Reflections',
                          icon: Icons.auto_stories_outlined,
                        ),
                        _MemoryStatChip(
                          label: '${stats.ingestionDocuments}',
                          caption: 'Docs',
                          icon: Icons.source_outlined,
                        ),
                        _MemoryStatChip(
                          label: stats.averageImportance.toStringAsFixed(1),
                          caption: 'Avg imp.',
                          icon: Icons.priority_high_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- Entity knowledge graph ---
        if (controller.memoryOverview.entities.isNotEmpty) ...<Widget>[
          _EntranceMotion(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: const _SectionTitle('Knowledge Graph')),
                        if (_entityFilter != null)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _entityFilter = null),
                            icon: Icon(Icons.close, size: 16),
                            label: Text('Clear filter'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap an entity to filter memories by it.',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: compact ? 260 : 320,
                      child: _EntityGraphView(
                        entities: controller.memoryOverview.entities,
                        knowledgeViews:
                            controller.memoryOverview.knowledgeViews,
                        selectedEntity: _entityFilter,
                        onEntityTapped: _onEntityTapped,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Tabbed content ---
        _EntranceMotion(
          child: Card(
            child: Column(
              children: <Widget>[
                TabBar(
                  controller: _tabController,
                  labelColor: _accentHover,
                  unselectedLabelColor: _textSecondary,
                  indicatorColor: _accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: _border,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                  tabs: <Widget>[
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.psychology_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('Memories'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.push_pin_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('Core'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.swap_horiz_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('Transfer'),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: <Widget>[
                        // --- Memories tab ---
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        labelText: 'Search memory',
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                      ),
                                      onSubmitted: (_) =>
                                          _runMemorySearch(controller),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton(
                                    onPressed: () =>
                                        _runMemorySearch(controller),
                                    child: Text('Search'),
                                  ),
                                  if (showingSearchResults ||
                                      _entityFilter != null) ...<Widget>[
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _resetMemorySearch(controller),
                                      child: Text('Reset'),
                                    ),
                                  ],
                                ],
                              ),
                              if (_entityFilter != null) ...<Widget>[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: <Widget>[
                                    _MetaPill(
                                      label: 'Entity: $_entityFilter',
                                      icon: Icons.filter_alt_outlined,
                                      color: _accent,
                                    ),
                                  ],
                                ),
                              ],
                              if (memoriesToShow.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      onPressed:
                                          allVisibleSelected ||
                                              _bulkActionInFlight
                                          ? null
                                          : () => _selectAllVisibleMemories(
                                              memoriesToShow,
                                            ),
                                      icon: Icon(
                                        Icons.done_all_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        allVisibleSelected
                                            ? 'All Selected'
                                            : 'Select All',
                                      ),
                                    ),
                                    if (selectedCount > 0) ...<Widget>[
                                      OutlinedButton.icon(
                                        onPressed: _bulkActionInFlight
                                            ? null
                                            : _clearMemorySelection,
                                        icon: Icon(
                                          Icons.deselect_outlined,
                                          size: 16,
                                        ),
                                        label: Text('Clear'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _bulkActionInFlight
                                            ? null
                                            : () => _runBulkMemoryAction(
                                                title:
                                                    'Archive selected memories?',
                                                message:
                                                    'Archive $selectedCount ${selectedCount == 1 ? 'memory' : 'memories'}?',
                                                confirmLabel: 'Archive',
                                                onConfirm:
                                                    controller.archiveMemories,
                                              ),
                                        icon: Icon(
                                          Icons.archive_outlined,
                                          size: 16,
                                        ),
                                        label: Text('Archive ($selectedCount)'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _bulkActionInFlight
                                            ? null
                                            : () => _runBulkMemoryAction(
                                                title:
                                                    'Delete selected memories?',
                                                message:
                                                    'Delete $selectedCount ${selectedCount == 1 ? 'memory' : 'memories'} permanently?',
                                                confirmLabel: 'Delete',
                                                onConfirm:
                                                    controller.deleteMemories,
                                              ),
                                        icon: Icon(
                                          Icons.delete_sweep_outlined,
                                          size: 16,
                                        ),
                                        label: Text('Delete ($selectedCount)'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (memoriesToShow.isEmpty)
                                Text(
                                  _entityFilter != null
                                      ? 'No memories linked to "$_entityFilter".'
                                      : 'No memory entries found.',
                                  style: TextStyle(color: _textSecondary),
                                )
                              else
                                ...memoriesToShow.map((memory) {
                                  final isSelected = selectedIds.contains(
                                    memory.id,
                                  );
                                  return _MemoryRow(
                                    memory: memory,
                                    isSelected: isSelected,
                                    onTap: () => _toggleMemorySelection(
                                      memory.id,
                                      !isSelected,
                                    ),
                                    onCheck: (value) => _toggleMemorySelection(
                                      memory.id,
                                      value ?? false,
                                    ),
                                    onDelete: _bulkActionInFlight
                                        ? null
                                        : () => _confirmDelete(
                                            context,
                                            title: 'Delete memory?',
                                            message:
                                                'This memory will be removed permanently.',
                                            onConfirm: () =>
                                                _deleteSingleMemory(
                                                  controller,
                                                  memory.id,
                                                ),
                                          ),
                                  );
                                }),
                            ],
                          ),
                        ),

                        // --- Core tab ---
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Key-value pairs that persist across conversations.',
                                      style: TextStyle(color: _textSecondary),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _openCoreMemoryEditor(
                                      context,
                                      controller,
                                    ),
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
                                ...controller.memoryOverview.coreEntries.entries
                                    .map((entry) {
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _bgSecondary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: _border),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    entry.key,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(entry.value.toString()),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _openCoreMemoryEditor(
                                                    context,
                                                    controller,
                                                    keyValue: entry,
                                                  ),
                                              icon: Icon(Icons.edit_outlined),
                                            ),
                                            IconButton(
                                              onPressed: () => _confirmDelete(
                                                context,
                                                title:
                                                    'Delete core memory entry?',
                                                message:
                                                    'Remove "${entry.key}" from core memory.',
                                                onConfirm: () =>
                                                    controller.deleteCoreMemory(
                                                      entry.key,
                                                    ),
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

                        // --- Transfer tab ---
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Generate a prompt for another AI, paste the response here to import memories.',
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
                                      _llmPromptLoading
                                          ? 'Generating...'
                                          : 'Generate Prompt',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _llmPromptController.text.trim().isEmpty
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
                                minLines: 4,
                                maxLines: 8,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Prompt to paste into another AI',
                                ),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _llmApplyBehaviorNotes,
                                onChanged: _llmImporting
                                    ? null
                                    : (value) => setState(
                                        () => _llmApplyBehaviorNotes = value,
                                      ),
                                title: Text('Apply behavior notes'),
                                subtitle: Text(
                                  'Overwrite behavior notes from the import.',
                                ),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _llmApplyCoreMemory,
                                onChanged: _llmImporting
                                    ? null
                                    : (value) => setState(
                                        () => _llmApplyCoreMemory = value,
                                      ),
                                title: Text('Apply core memory'),
                                subtitle: Text(
                                  'Update core memory entries from the import.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _llmImportController,
                                minLines: 4,
                                maxLines: 10,
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
                                label: Text(
                                  _llmImporting ? 'Importing...' : 'Import',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                    if (value != null) category = value;
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
                if (context.mounted) Navigator.of(context).pop();
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
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _MemoryStatChip extends StatelessWidget {
  const _MemoryStatChip({
    required this.label,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      blurSigma: 10,
      fillColor: _bgSecondary.withValues(alpha: 0.7),
      borderColor: _borderLight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: _accentAlt),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  color: _textPrimary,
                ),
              ),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryConfidenceGauge extends StatefulWidget {
  const _MemoryConfidenceGauge({required this.confidence});

  final double confidence;

  @override
  State<_MemoryConfidenceGauge> createState() => _MemoryConfidenceGaugeState();
}

class _MemoryConfidenceGaugeState extends State<_MemoryConfidenceGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = Tween<double>(
      begin: 0,
      end: widget.confidence,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_MemoryConfidenceGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confidence != widget.confidence) {
      _progress = Tween<double>(begin: _progress.value, end: widget.confidence)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final value = _progress.value;
        final percent = (value * 100).round();
        return SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _RadialGaugePainter(
              progress: value,
              trackColor: _border,
              fillColor: _accent,
              glowColor: _accentHover,
            ),
            child: Center(
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  const _RadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.glowColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const startAngle = -math.pi / 2;
    const totalAngle = 2 * math.pi;
    final sweepAngle = totalAngle * progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalAngle,
      false,
      trackPaint,
    );

    if (sweepAngle > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      final fillPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: <Color>[fillColor, glowColor],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadialGaugePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      fillColor != oldDelegate.fillColor;
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({
    required this.memory,
    required this.isSelected,
    required this.onTap,
    required this.onCheck,
    this.onDelete,
  });

  final MemoryItem memory;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool?> onCheck;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _accentMuted : _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? _accent : _border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(value: isSelected, onChanged: onCheck),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _MetaPill(
                                  label: memory.category,
                                  icon: Icons.label_outline,
                                ),
                                _MetaPill(
                                  label: 'Imp ${memory.importance}',
                                  icon: Icons.priority_high_outlined,
                                ),
                                _MetaPill(
                                  label: '${memory.confidencePercent}%',
                                  icon: Icons.verified_outlined,
                                ),
                              ],
                            ),
                          ),
                          if (onDelete != null)
                            IconButton(
                              onPressed: onDelete,
                              icon: Icon(Icons.delete_outline, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(memory.content),
                      if (memory.entities.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: memory.entities
                              .take(5)
                              .map(
                                (e) => _MetaPill(
                                  label: e.name,
                                  icon: Icons.hub_outlined,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        memory.createdAtLabel,
                        style: TextStyle(fontSize: 11, color: _textMuted),
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
  }
}

// ---------------------------------------------------------------------------
// Interactive Entity Knowledge Graph
// ---------------------------------------------------------------------------

class _EntityGraphView extends StatefulWidget {
  const _EntityGraphView({
    required this.entities,
    required this.knowledgeViews,
    this.selectedEntity,
    this.onEntityTapped,
  });

  final List<MemoryEntity> entities;
  final List<KnowledgeViewItem> knowledgeViews;
  final String? selectedEntity;
  final ValueChanged<String>? onEntityTapped;

  @override
  State<_EntityGraphView> createState() => _EntityGraphViewState();
}

class _EntityGraphViewState extends State<_EntityGraphView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleController;
  final List<_GraphNode> _nodes = <_GraphNode>[];
  String? _hoveredNode;
  bool _layoutDone = false;
  Size? _lastLayoutSize;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _buildNodes();
  }

  @override
  void didUpdateWidget(_EntityGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entities != widget.entities ||
        oldWidget.knowledgeViews != widget.knowledgeViews) {
      _buildNodes();
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  static const Map<String, Color> _kindColors = <String, Color>{
    'person': Color(0xFF9B8AE0),
    'project': Color(0xFF5E9B7C),
    'file': Color(0xFF7BA5C7),
    'concept': Color(0xFFB8A06B),
    'tool': Color(0xFFCF8F6B),
    'organization': Color(0xFF7DA0B5),
  };

  void _buildNodes() {
    _nodes.clear();
    final entities = widget.entities;
    final views = widget.knowledgeViews;
    final maxMention = entities.fold<int>(
      1,
      (max, e) => e.mentionCount > max ? e.mentionCount : max,
    );

    for (int i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final sizeFactor = 0.4 + 0.6 * (entity.mentionCount / maxMention);
      _nodes.add(
        _GraphNode(
          id: entity.name,
          label: entity.name,
          radius: 18 + 20 * sizeFactor,
          color: _kindColors[entity.kind] ?? _kindColors['concept']!,
          kind: entity.kind,
          isReflection: false,
          offsetPhase: i * 0.7,
        ),
      );
    }

    for (int i = 0; i < views.length && i < 6; i++) {
      _nodes.add(
        _GraphNode(
          id: 'kv_${views[i].title}',
          label: views[i].title,
          radius: 14,
          color: const Color(0xFF8B7EC8),
          kind: views[i].viewType,
          isReflection: true,
          offsetPhase: (entities.length + i) * 0.9,
        ),
      );
    }

    _layoutDone = false;
  }

  void _layoutNodes(Size size) {
    if (_nodes.isEmpty) return;
    if (_layoutDone && _lastLayoutSize == size) return;
    _layoutDone = true;
    _lastLayoutSize = size;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radiusX = size.width * 0.35;
    final radiusY = size.height * 0.35;

    for (int i = 0; i < _nodes.length; i++) {
      final angle = (2 * math.pi * i / _nodes.length) - math.pi / 2;
      final jitter = (i.isEven ? 0.85 : 1.0) + (i % 3) * 0.05;
      _nodes[i].x = cx + radiusX * jitter * math.cos(angle);
      _nodes[i].y = cy + radiusY * jitter * math.sin(angle);
    }
  }

  void _handleTap(Offset localPosition) {
    for (final node in _nodes.reversed) {
      final dx = localPosition.dx - node.x;
      final dy = localPosition.dy - node.y;
      if (dx * dx + dy * dy <= node.radius * node.radius * 1.8) {
        if (!node.isReflection) {
          widget.onEntityTapped?.call(node.label);
        }
        return;
      }
    }
  }

  void _handleHover(Offset? localPosition) {
    if (localPosition == null) {
      if (_hoveredNode != null) setState(() => _hoveredNode = null);
      return;
    }
    String? found;
    for (final node in _nodes.reversed) {
      final dx = localPosition.dx - node.x;
      final dy = localPosition.dy - node.y;
      if (dx * dx + dy * dy <= node.radius * node.radius * 1.8) {
        found = node.id;
        break;
      }
    }
    if (found != _hoveredNode) setState(() => _hoveredNode = found);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _layoutNodes(size);
        return MouseRegion(
          onHover: (event) => _handleHover(event.localPosition),
          onExit: (_) => _handleHover(null),
          child: GestureDetector(
            onTapDown: (details) => _handleTap(details.localPosition),
            child: AnimatedBuilder(
              animation: _idleController,
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _EntityGraphPainter(
                    nodes: _nodes,
                    selectedEntity: widget.selectedEntity,
                    hoveredNode: _hoveredNode,
                    animationValue: _idleController.value,
                    accentColor: _accent,
                    bgColor: _bgSecondary,
                    textColor: _textPrimary,
                    mutedTextColor: _textSecondary,
                    borderColor: _border,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _GraphNode {
  _GraphNode({
    required this.id,
    required this.label,
    required this.radius,
    required this.color,
    required this.kind,
    required this.isReflection,
    required this.offsetPhase,
  });

  final String id;
  final String label;
  final double radius;
  final Color color;
  final String kind;
  final bool isReflection;
  final double offsetPhase;
  double x = 0;
  double y = 0;
}

class _EntityGraphPainter extends CustomPainter {
  const _EntityGraphPainter({
    required this.nodes,
    required this.selectedEntity,
    required this.hoveredNode,
    required this.animationValue,
    required this.accentColor,
    required this.bgColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
  });

  final List<_GraphNode> nodes;
  final String? selectedEntity;
  final String? hoveredNode;
  final double animationValue;
  final Color accentColor;
  final Color bgColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final entityNodes = nodes
        .where((n) => !n.isReflection)
        .toList(growable: false);
    final reflectionNodes = nodes
        .where((n) => n.isReflection)
        .toList(growable: false);

    // Draw connections between entity nodes (subtle web)
    final linePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (int i = 0; i < entityNodes.length; i++) {
      for (int j = i + 1; j < entityNodes.length; j++) {
        if ((i + j) % 3 != 0) continue;
        final a = entityNodes[i];
        final b = entityNodes[j];
        final drift = math.sin(animationValue * 2 * math.pi + a.offsetPhase);
        canvas.drawLine(
          Offset(a.x, a.y + drift * 2),
          Offset(b.x, b.y + drift * 2),
          linePaint,
        );
      }
    }

    // Draw connections from reflections to closest entity
    if (entityNodes.isNotEmpty) {
      final reflectionLinePaint = Paint()
        ..color = borderColor.withValues(alpha: 0.14)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (final rn in reflectionNodes) {
        final drift =
            math.sin(animationValue * 2 * math.pi + rn.offsetPhase) * 3;
        var closest = entityNodes.first;
        var minDist = double.infinity;
        for (final en in entityNodes) {
          final d =
              (en.x - rn.x) * (en.x - rn.x) + (en.y - rn.y) * (en.y - rn.y);
          if (d < minDist) {
            minDist = d;
            closest = en;
          }
        }
        canvas.drawLine(
          Offset(rn.x, rn.y + drift),
          Offset(closest.x, closest.y + drift),
          reflectionLinePaint,
        );
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final drift =
          math.sin(animationValue * 2 * math.pi + node.offsetPhase) * 3;
      final isSelected = node.label == selectedEntity;
      final isHovered = node.id == hoveredNode;
      final cx = node.x;
      final cy = node.y + drift;
      final r = node.radius * (isHovered ? 1.15 : 1.0);

      // Glow
      if (isSelected || isHovered) {
        final glowPaint = Paint()
          ..color = (isSelected ? accentColor : node.color).withValues(
            alpha: 0.22,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(cx, cy), r + 6, glowPaint);
      }

      // Fill
      final fillPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            node.color.withValues(alpha: isSelected ? 0.9 : 0.7),
            node.color.withValues(alpha: isSelected ? 0.6 : 0.35),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = isSelected
            ? accentColor
            : (isHovered
                  ? node.color.withValues(alpha: 0.8)
                  : node.color.withValues(alpha: 0.35))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawCircle(Offset(cx, cy), r, borderPaint);

      // Label
      final labelStyle = TextStyle(
        color: isSelected ? textColor : mutedTextColor,
        fontSize: node.isReflection ? 9 : 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      );
      final tp = TextPainter(
        text: TextSpan(text: node.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: r * 3);
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + r + 5));
    }
  }

  @override
  bool shouldRepaint(_EntityGraphPainter oldDelegate) => true;
}

String _manualRunButtonLabel(String label, int remainingSeconds) {
  if (remainingSeconds <= 0) {
    return label;
  }
  return '$label (${remainingSeconds}s)';
}

class _TaskTriggerOption {
  const _TaskTriggerOption({
    required this.type,
    required this.section,
    required this.label,
    required this.description,
    required this.icon,
    this.providerKey,
    this.appKey,
  });

  final String type;
  final String section;
  final String label;
  final String description;
  final IconData icon;

  /// The official integration provider key this trigger binds to, if any.
  /// When set, the task editor shows a connected-account dropdown instead of
  /// a raw connection ID text field.
  final String? providerKey;

  /// The app within the provider (matches [OfficialIntegrationAppItem.id]).
  /// Narrows account lookup to just the relevant app so multi-app providers
  /// (e.g. Google Workspace with Gmail + Drive + Calendar) don't show
  /// duplicate accounts.
  final String? appKey;
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
    providerKey: 'google_workspace',
    appKey: 'gmail',
  ),
  _TaskTriggerOption(
    type: 'outlook_email_received',
    section: 'Email',
    label: 'Outlook Email Received',
    description: 'Run when a matching Outlook email arrives.',
    icon: Icons.markunread_rounded,
    providerKey: 'microsoft_365',
    appKey: 'outlook',
  ),
  _TaskTriggerOption(
    type: 'slack_message_received',
    section: 'Messaging',
    label: 'Slack Message Received',
    description: 'Run when a Slack message matches the selected scope.',
    icon: Icons.forum_rounded,
    providerKey: 'slack',
    appKey: 'slack',
  ),
  _TaskTriggerOption(
    type: 'teams_message_received',
    section: 'Messaging',
    label: 'Teams Message Received',
    description: 'Run when a Teams chat message matches the selected scope.',
    icon: Icons.groups_rounded,
    providerKey: 'microsoft_365',
    appKey: 'teams',
  ),
  _TaskTriggerOption(
    type: 'weather_event',
    section: 'Environment',
    label: 'Weather Event',
    description:
        'Run when configured weather events are forecast for a location.',
    icon: Icons.cloudy_snowing,
    providerKey: 'weather',
    appKey: 'forecast',
  ),
  _TaskTriggerOption(
    type: 'whatsapp_personal_message_received',
    section: 'Messaging',
    label: 'WhatsApp Personal Message Received',
    description: 'Run on inbound personal WhatsApp messages.',
    icon: Icons.chat_bubble_rounded,
    providerKey: 'whatsapp_personal',
    appKey: 'personal',
  ),
  _TaskTriggerOption(
    type: 'android_notification_received',
    section: 'System',
    label: 'Android Notification Received',
    description: 'Run when a notification arrives on your device.',
    icon: Icons.notifications_active_rounded,
  ),
];

_TaskTriggerOption _taskTriggerOptionForType(String type) {
  return _taskTriggerOptions.firstWhere(
    (option) => option.type == type,
    orElse: () => _taskTriggerOptions.first,
  );
}

class _TaskSchedulePreset {
  const _TaskSchedulePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

const List<_TaskSchedulePreset> _taskSchedulePresets = <_TaskSchedulePreset>[
  _TaskSchedulePreset(
    id: 'every_15_minutes',
    label: 'Every 15 minutes',
    description: 'Runs four times per hour.',
    icon: Icons.timer_outlined,
  ),
  _TaskSchedulePreset(
    id: 'every_30_minutes',
    label: 'Every 30 minutes',
    description: 'Runs twice per hour.',
    icon: Icons.timelapse_rounded,
  ),
  _TaskSchedulePreset(
    id: 'hourly',
    label: 'Hourly',
    description: 'Runs once per hour.',
    icon: Icons.schedule_rounded,
  ),
  _TaskSchedulePreset(
    id: 'daily',
    label: 'Daily',
    description: 'Runs every day at the selected time.',
    icon: Icons.today_rounded,
  ),
  _TaskSchedulePreset(
    id: 'weekdays',
    label: 'Weekdays',
    description: 'Runs Monday through Friday.',
    icon: Icons.work_outline_rounded,
  ),
  _TaskSchedulePreset(
    id: 'weekly',
    label: 'Weekly',
    description: 'Runs on selected weekdays.',
    icon: Icons.view_week_rounded,
  ),
  _TaskSchedulePreset(
    id: 'monthly',
    label: 'Monthly',
    description: 'Runs once per month on the selected day.',
    icon: Icons.calendar_month_rounded,
  ),
  _TaskSchedulePreset(
    id: 'custom',
    label: 'Custom Cron',
    description: 'Advanced manual schedule for special cases.',
    icon: Icons.tune_rounded,
  ),
];

const List<String> _taskWeekdayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

_TaskSchedulePreset _taskSchedulePresetForId(String id) {
  return _taskSchedulePresets.firstWhere(
    (entry) => entry.id == id,
    orElse: () => _taskSchedulePresets[1],
  );
}

class _TaskScheduleDraft {
  _TaskScheduleDraft({
    required this.mode,
    required this.presetId,
    required this.time,
    required this.weekdays,
    required this.monthDay,
    required this.customCronExpression,
  });

  factory _TaskScheduleDraft.fromTask(TaskItem? task) {
    final runAt = task?.triggerConfig['runAt']?.toString().trim() ?? '';
    if (runAt.isNotEmpty) {
      return _TaskScheduleDraft(
        mode: 'one_time',
        presetId: 'daily',
        time: const TimeOfDay(hour: 9, minute: 0),
        weekdays: <int>{1},
        monthDay: 1,
        customCronExpression: '',
      );
    }
    final cron =
        task?.triggerConfig['cronExpression']?.toString().trim() ??
        '*/30 * * * *';
    final parsed = _parseCronExpression(cron);
    if (parsed != null) return parsed;
    return _TaskScheduleDraft(
      mode: 'recurring',
      presetId: 'custom',
      time: const TimeOfDay(hour: 9, minute: 0),
      weekdays: <int>{1},
      monthDay: 1,
      customCronExpression: cron,
    );
  }

  String mode;
  String presetId;
  TimeOfDay time;
  Set<int> weekdays;
  int monthDay;
  String customCronExpression;

  bool get usesTime =>
      presetId == 'daily' ||
      presetId == 'weekdays' ||
      presetId == 'weekly' ||
      presetId == 'monthly';

  String get cronExpression {
    if (presetId == 'custom') return customCronExpression;
    final minute = time.minute.toString();
    final hour = time.hour.toString();
    return switch (presetId) {
      'every_15_minutes' => '*/15 * * * *',
      'every_30_minutes' => '*/30 * * * *',
      'hourly' => '0 * * * *',
      'daily' => '$minute $hour * * *',
      'weekdays' => '$minute $hour * * 1-5',
      'weekly' => '$minute $hour * * ${_cronWeekdays(weekdays)}',
      'monthly' => '$minute $hour $monthDay * *',
      'custom' => customCronExpression,
      _ => '*/30 * * * *',
    };
  }

  String get summary {
    if (mode == 'one_time') return 'One-time run';
    if (presetId == 'custom') return 'Custom Cron';
    final preset = _taskSchedulePresetForId(presetId);
    if (!usesTime) return preset.label;
    final timeLabel = _formatTaskScheduleTime(time);
    if (presetId == 'weekly') {
      return '${preset.label} ${_formatTaskWeekdays(weekdays)} at $timeLabel';
    }
    if (presetId == 'monthly') {
      return '${preset.label} on day $monthDay at $timeLabel';
    }
    return '${preset.label} at $timeLabel';
  }
}

_TaskScheduleDraft? _parseCronExpression(String cron) {
  final fields = cron.trim().split(RegExp(r'\s+'));
  if (fields.length != 5) return null;
  final minute = fields[0];
  final hour = fields[1];
  final dayOfMonth = fields[2];
  final month = fields[3];
  final dayOfWeek = fields[4];
  if (cron == '*/15 * * * *') {
    return _recurringScheduleDraft('every_15_minutes');
  }
  if (cron == '*/30 * * * *') {
    return _recurringScheduleDraft('every_30_minutes');
  }
  if (cron == '0 * * * *') return _recurringScheduleDraft('hourly');
  final parsedMinute = int.tryParse(minute);
  final parsedHour = int.tryParse(hour);
  if (parsedMinute == null ||
      parsedMinute < 0 ||
      parsedMinute > 59 ||
      parsedHour == null ||
      parsedHour < 0 ||
      parsedHour > 23 ||
      month != '*') {
    return null;
  }
  final time = TimeOfDay(hour: parsedHour, minute: parsedMinute);
  if (dayOfMonth == '*' && dayOfWeek == '*') {
    return _recurringScheduleDraft('daily', time: time);
  }
  if (dayOfMonth == '*' && dayOfWeek == '1-5') {
    return _recurringScheduleDraft('weekdays', time: time);
  }
  if (dayOfMonth == '*') {
    final weekdays = _parseCronWeekdays(dayOfWeek);
    if (weekdays == null || weekdays.isEmpty) return null;
    return _recurringScheduleDraft('weekly', time: time, weekdays: weekdays);
  }
  if (dayOfWeek == '*') {
    final parsedDay = int.tryParse(dayOfMonth);
    if (parsedDay == null || parsedDay < 1 || parsedDay > 31) return null;
    return _recurringScheduleDraft('monthly', time: time, monthDay: parsedDay);
  }
  return null;
}

bool _looksLikeCronExpression(String cron) {
  return cron.trim().split(RegExp(r'\s+')).length == 5;
}

_TaskScheduleDraft _recurringScheduleDraft(
  String presetId, {
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0),
  Set<int> weekdays = const <int>{1},
  int monthDay = 1,
}) {
  return _TaskScheduleDraft(
    mode: 'recurring',
    presetId: presetId,
    time: time,
    weekdays: Set<int>.from(weekdays),
    monthDay: monthDay,
    customCronExpression: '',
  );
}

Set<int>? _parseCronWeekdays(String value) {
  final result = <int>{};
  for (final part in value.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return null;
    final rangeParts = trimmed.split('-');
    if (rangeParts.length == 2) {
      final start = _parseCronWeekday(rangeParts[0]);
      final end = _parseCronWeekday(rangeParts[1]);
      if (start == null || end == null || start > end) return null;
      for (var day = start; day <= end; day += 1) {
        result.add(day);
      }
    } else if (rangeParts.length == 1) {
      final day = _parseCronWeekday(trimmed);
      if (day == null) return null;
      result.add(day);
    } else {
      return null;
    }
  }
  return result;
}

int? _parseCronWeekday(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0 || parsed > 7) return null;
  return parsed == 0 ? 7 : parsed;
}

String _cronWeekdays(Set<int> weekdays) {
  final sorted = weekdays.where((day) => day >= 1 && day <= 7).toList()..sort();
  if (sorted.isEmpty) return '1';
  return sorted.join(',');
}

String _formatTaskScheduleTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTaskWeekdays(Set<int> weekdays) {
  final sorted = weekdays.where((day) => day >= 1 && day <= 7).toList()..sort();
  if (sorted.isEmpty) return 'Monday';
  return sorted.map((day) => _taskWeekdayLabels[day - 1]).join(', ');
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

IconData _taskDeliveryPlatformIcon(String platform) {
  for (final descriptor in messagingPlatforms) {
    if (descriptor.id == platform) return descriptor.icon;
  }
  return Icons.forum_rounded;
}

Color _taskDeliveryPlatformColor(String platform) {
  for (final descriptor in messagingPlatforms) {
    if (descriptor.id == platform) return descriptor.accent;
  }
  return _accent;
}

String _taskDeliveryPlatformLabel(String platform) {
  for (final descriptor in messagingPlatforms) {
    if (descriptor.id == platform) return descriptor.label;
  }
  return platform.replaceAll('_', ' ').toUpperCase();
}

TaskDeliveryTarget? _taskDeliveryTargetFromTask(TaskItem? task) {
  final platform = task?.taskConfig['notifyPlatform']?.toString().trim() ?? '';
  final to = task?.taskConfig['notifyTo']?.toString().trim() ?? '';
  if (platform.isEmpty || to.isEmpty) return null;
  return TaskDeliveryTarget(
    platform: platform,
    platformLabel: _taskDeliveryPlatformLabel(platform),
    to: to,
    label: to,
    subtitle: 'Saved delivery destination',
    source: 'manual',
    connected: true,
    supportsDelivery: true,
  );
}

List<DropdownMenuItem<String>> _taskModelOverrideItems({
  required String selectedModel,
  required List<ModelMeta> models,
}) {
  final availableModels = models.where((model) => model.available).toList();
  final availableIds = availableModels.map((model) => model.id).toSet();
  final selectedModelMeta = _modelForValue(selectedModel, models);
  final selectedModelIsUnavailable =
      selectedModel != 'auto' && !availableIds.contains(selectedModel);

  return <DropdownMenuItem<String>>[
    const DropdownMenuItem<String>(
      value: 'auto',
      child: Text('Auto (default routing)'),
    ),
    if (selectedModelIsUnavailable)
      DropdownMenuItem<String>(
        value: selectedModel,
        enabled: false,
        child: Text(
          '${selectedModelMeta?.label ?? selectedModel} (Unavailable saved override)',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ...availableModels.map(
      (model) => DropdownMenuItem<String>(
        value: model.id,
        child: Text(model.label, overflow: TextOverflow.ellipsis),
      ),
    ),
  ];
}

Future<TaskDeliveryTarget?> _pickTaskDeliveryTarget(
  BuildContext context, {
  required NeoAgentController controller,
  required String? agentId,
  required TaskDeliveryTarget? selected,
}) {
  return showModalBottomSheet<TaskDeliveryTarget?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _bgCard,
    builder: (context) => _TaskDeliveryTargetPickerSheet(
      controller: controller,
      agentId: agentId,
      selected: selected,
    ),
  );
}

class _TaskDeliveryTargetPickerSheet extends StatefulWidget {
  const _TaskDeliveryTargetPickerSheet({
    required this.controller,
    required this.agentId,
    required this.selected,
  });

  final NeoAgentController controller;
  final String? agentId;
  final TaskDeliveryTarget? selected;

  @override
  State<_TaskDeliveryTargetPickerSheet> createState() =>
      _TaskDeliveryTargetPickerSheetState();
}

class _TaskDeliveryTargetPickerSheetState
    extends State<_TaskDeliveryTargetPickerSheet> {
  late final TextEditingController _queryController;
  late final TextEditingController _manualController;
  Timer? _debounce;
  Future<List<TaskDeliveryTarget>>? _targetsFuture;
  String? _platformFilter;
  String? _manualPlatform;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _manualController = TextEditingController();
    _manualPlatform = widget.selected?.platform;
    _loadTargets();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _loadTargets() {
    setState(() {
      _targetsFuture = widget.controller.fetchTaskDeliveryTargets(
        query: _queryController.text,
        platform: _platformFilter,
        agentId: widget.agentId,
      );
    });
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _loadTargets);
  }

  List<String> _platformIds(List<TaskDeliveryTarget> targets) {
    final ids = <String>{
      if (widget.selected?.platform.isNotEmpty == true)
        widget.selected!.platform,
      ...targets.map((target) => target.platform),
      ...messagingPlatforms
          .where(
            (platform) =>
                platform.id == 'whatsapp' ||
                platform.id == 'discord' ||
                platform.id == 'telegram' ||
                platform.id == 'slack',
          )
          .map((platform) => platform.id),
    }.toList();
    ids.sort(
      (left, right) => _taskDeliveryPlatformLabel(
        left,
      ).compareTo(_taskDeliveryPlatformLabel(right)),
    );
    return ids;
  }

  void _submitManual() {
    final to = _manualController.text.trim();
    final platform =
        _manualPlatform ?? _platformFilter ?? widget.selected?.platform ?? '';
    if (to.isEmpty || platform.isEmpty) return;
    Navigator.of(context).pop(
      TaskDeliveryTarget(
        platform: platform,
        platformLabel: _taskDeliveryPlatformLabel(platform),
        to: to,
        label: to,
        subtitle: 'Manual destination',
        source: 'manual',
        connected: true,
        supportsDelivery: true,
      ),
    );
  }

  Widget _buildTargetTile(TaskDeliveryTarget target) {
    final color = _taskDeliveryPlatformColor(target.platform);
    final selected = widget.selected?.id == target.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_taskDeliveryPlatformIcon(target.platform), color: color),
      ),
      title: Text(
        target.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${target.platformLabel} · ${target.subtitle.ifEmpty(target.to)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _StatusPill(label: target.sourceLabel, color: color),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
            color: selected ? color : _textSecondary,
          ),
        ],
      ),
      enabled: target.selectable,
      onTap: target.selectable ? () => Navigator.of(context).pop(target) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: FutureBuilder<List<TaskDeliveryTarget>>(
          future: _targetsFuture,
          builder: (context, snapshot) {
            final targets = snapshot.data ?? const <TaskDeliveryTarget>[];
            final platformIds = _platformIds(targets);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Result Delivery',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(
                          const TaskDeliveryTarget(
                            platform: '',
                            platformLabel: '',
                            to: '',
                            label: '',
                            subtitle: '',
                            source: 'default',
                            connected: true,
                            supportsDelivery: true,
                          ),
                        ),
                        icon: const Icon(Icons.auto_mode_rounded),
                        label: const Text('Use default'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search discovered messaging channels, contacts, groups, and recent conversations.',
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _queryController,
                    onChanged: (_) => _scheduleSearch(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Search channels',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: _platformFilter == null,
                            onSelected: (_) {
                              _platformFilter = null;
                              _loadTargets();
                            },
                          ),
                        ),
                        ...platformIds.map((platform) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                _taskDeliveryPlatformIcon(platform),
                                size: 16,
                              ),
                              label: Text(_taskDeliveryPlatformLabel(platform)),
                              selected: _platformFilter == platform,
                              onSelected: (_) {
                                _platformFilter = platform;
                                _loadTargets();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    _TaskDeliveryNotice(
                      icon: Icons.warning_amber_rounded,
                      title: 'Discovery failed',
                      detail: snapshot.error.toString(),
                    )
                  else if (targets.isEmpty)
                    _TaskDeliveryNotice(
                      icon: Icons.search_off_rounded,
                      title: 'No channels found',
                      detail:
                          'Try another search, connect a messaging platform, or enter a destination ID manually.',
                    )
                  else
                    ...targets.take(40).map(_buildTargetTile),
                  const Divider(height: 28),
                  Text(
                    'Manual destination',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _manualPlatform,
                          decoration: const InputDecoration(
                            labelText: 'Platform',
                          ),
                          items: platformIds
                              .map(
                                (platform) => DropdownMenuItem<String>(
                                  value: platform,
                                  child: Text(
                                    _taskDeliveryPlatformLabel(platform),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) =>
                              setState(() => _manualPlatform = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            labelText: 'Destination ID',
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Use manual destination',
                        onPressed: _submitManual,
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskDeliveryNotice extends StatelessWidget {
  const _TaskDeliveryNotice({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: _textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(color: _textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

  Color _taskRunStatusColor(String status) {
    switch (status) {
      case 'completed':
        return _success;
      case 'failed':
      case 'error':
        return _danger;
      case 'running':
      case 'retrying':
        return _warning;
      default:
        return _textSecondary;
    }
  }

  Future<void> _showLastRun(TaskItem task) async {
    final runId = task.lastRunId.trim();
    if (runId.isEmpty) return;

    try {
      final detail = await controller.fetchRunDetail(runId, force: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(detail.run.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StatusPill(
                        label: detail.run.statusLabel,
                        color: detail.run.statusColor,
                      ),
                      _StatusPill(
                        label: '${detail.steps.length} steps',
                        color: _textSecondary,
                      ),
                    ],
                  ),
                  if (detail.run.error.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(detail.run.error, style: TextStyle(color: _danger)),
                  ],
                  if (detail.response.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    SelectableText(detail.response),
                  ],
                  if (detail.response.trim().isEmpty &&
                      detail.run.error.trim().isEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'This run did not produce a user-facing response.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.friendlyErrorMessage(error))),
      );
    }
  }

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
    final selectedAgentLabel = controller.agentLabelFor(_agentFilterId);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Tasks',
          subtitle:
              'Premium automation with schedule and integration triggers.',
          trailing: FilledButton.icon(
            onPressed: () => _openTaskEditor(
              context,
              defaultAgentId: _agentFilterId ?? controller.selectedAgentId,
            ),
            icon: Icon(Icons.add),
            label: Text('Add Task'),
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
        else
          ...filteredTasks.map(_buildTaskCard),
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
                  if (task.loopPaused) ...<Widget>[
                    const SizedBox(width: 8),
                    _StatusPill(label: 'Loop paused', color: _warning),
                  ],
                  if (task.hasLastRunStatus) ...<Widget>[
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: 'Last: ${task.lastRunStatusLabel}',
                      color: _taskRunStatusColor(task.lastRunStatus),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.scheduleLabel,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: GoogleFonts.geistMono().fontFamily,
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
              if (task.lastRunFailed &&
                  task.lastRunError.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(task.lastRunError, style: TextStyle(color: _danger)),
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
                  if (task.lastRunId.trim().isNotEmpty)
                    OutlinedButton(
                      onPressed: () => _showLastRun(task),
                      child: const Text('View last run'),
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

  List<OfficialIntegrationAccountItem> _connectedAccountsForTrigger(
    String triggerType,
  ) {
    final option = _taskTriggerOptionForType(triggerType);
    final providerKey = option.providerKey;
    if (providerKey == null) return const <OfficialIntegrationAccountItem>[];
    final appKey = option.appKey;
    final seen = <int>{};
    final result = <OfficialIntegrationAccountItem>[];
    for (final integration in controller.officialIntegrations) {
      if (integration.id != providerKey) continue;
      for (final app in integration.apps) {
        if (appKey != null && app.id != appKey) continue;
        for (final account in app.accounts) {
          if (account.connected && seen.add(account.id)) {
            result.add(account);
          }
        }
      }
    }
    return result;
  }

  Widget _buildConnectionIdSelector({
    required String triggerType,
    required ValueNotifier<int?> selectedConnectionId,
    required TextEditingController fallbackController,
    required StateSetter setLocalState,
  }) {
    final accounts = _connectedAccountsForTrigger(triggerType);
    if (accounts.isEmpty) {
      return TextField(
        controller: fallbackController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Connection ID',
          helperText: 'Connect this integration first to pick an account.',
        ),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: accounts.any((a) => a.id == selectedConnectionId.value)
          ? selectedConnectionId.value
          : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Account'),
      items: accounts
          .map(
            (account) => DropdownMenuItem<int>(
              value: account.id,
              child: Text(account.accountEmail ?? 'Account #${account.id}'),
            ),
          )
          .toList(),
      onChanged: (value) =>
          setLocalState(() => selectedConnectionId.value = value),
    );
  }

  Future<void> _openTaskEditor(
    BuildContext context, {
    TaskItem? task,
    String? defaultAgentId,
  }) async {
    final nameController = TextEditingController(text: task?.name ?? '');
    final triggerType = ValueNotifier<String>(task?.triggerType ?? 'schedule');
    final scheduleDraft = _TaskScheduleDraft.fromTask(task);
    final customCronController = TextEditingController(
      text: scheduleDraft.customCronExpression,
    );
    final runAtController = TextEditingController(
      text: task?.triggerConfig['runAt']?.toString() ?? '',
    );
    final connectionIdController = TextEditingController(
      text: task?.triggerConfig['connectionId']?.toString() ?? '',
    );
    final selectedConnectionId = ValueNotifier<int?>(
      task?.triggerConfig['connectionId'] is int
          ? task!.triggerConfig['connectionId'] as int
          : int.tryParse(task?.triggerConfig['connectionId']?.toString() ?? ''),
    );
    final selectedDeliveryTarget = ValueNotifier<TaskDeliveryTarget?>(
      _taskDeliveryTargetFromTask(task),
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
    var loopPaused = task?.loopPaused ?? false;
    var unreadOnly = task?.triggerConfig['unreadOnly'] == true;
    var ignoreGroups = task?.triggerConfig['ignoreGroups'] == true;
    var selectedModel = _ensureModelValue(
      task?.model ?? 'auto',
      controller.supportedModels,
      allowAuto: true,
      preserveUnknown: true,
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
                                selectedConnectionId.value = null;
                                connectionIdController.clear();
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
                                SegmentedButton<String>(
                                  segments: const <ButtonSegment<String>>[
                                    ButtonSegment<String>(
                                      value: 'recurring',
                                      icon: Icon(Icons.repeat_rounded),
                                      label: Text('Recurring'),
                                    ),
                                    ButtonSegment<String>(
                                      value: 'one_time',
                                      icon: Icon(Icons.event_rounded),
                                      label: Text('Once'),
                                    ),
                                  ],
                                  selected: <String>{scheduleDraft.mode},
                                  onSelectionChanged: (selection) {
                                    setLocalState(() {
                                      scheduleDraft.mode = selection.first;
                                      if (scheduleDraft.mode == 'recurring') {
                                        runAtController.clear();
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (scheduleDraft.mode == 'one_time')
                                  TextField(
                                    controller: runAtController,
                                    decoration: const InputDecoration(
                                      labelText: 'Run At',
                                      helperText:
                                          'Use a date and time, for example 2026-07-03T09:00:00.',
                                    ),
                                  )
                                else ...<Widget>[
                                  DropdownButtonFormField<String>(
                                    initialValue: scheduleDraft.presetId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Repeat',
                                    ),
                                    items: <DropdownMenuItem<String>>[
                                      ..._taskSchedulePresets.map(
                                        (preset) => DropdownMenuItem<String>(
                                          value: preset.id,
                                          child: Text(preset.label),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setLocalState(() {
                                        final currentCron =
                                            scheduleDraft.cronExpression;
                                        scheduleDraft.presetId = value;
                                        if (value == 'custom' &&
                                            customCronController.text
                                                .trim()
                                                .isEmpty) {
                                          customCronController.text =
                                              currentCron;
                                          scheduleDraft.customCronExpression =
                                              currentCron;
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  if (scheduleDraft.presetId ==
                                      'custom') ...<Widget>[
                                    TextField(
                                      controller: customCronController,
                                      onChanged: (value) =>
                                          scheduleDraft.customCronExpression =
                                              value,
                                      decoration: const InputDecoration(
                                        labelText: 'Cron expression',
                                        helperText:
                                            'Advanced: minute hour day month weekday.',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (scheduleDraft.usesTime) ...<Widget>[
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: scheduleDraft.time,
                                          builder: (context, child) {
                                            return MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    alwaysUse24HourFormat: true,
                                                  ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked == null) return;
                                        setLocalState(() {
                                          scheduleDraft.time = picked;
                                        });
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Time',
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            const Icon(
                                              Icons.access_time_rounded,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _formatTaskScheduleTime(
                                                  scheduleDraft.time,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.unfold_more_rounded,
                                              color: _textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (scheduleDraft.presetId ==
                                      'weekly') ...<Widget>[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: List<Widget>.generate(7, (
                                          index,
                                        ) {
                                          final day = index + 1;
                                          return ChoiceChip(
                                            label: Text(
                                              _taskWeekdayLabels[index],
                                            ),
                                            selected: scheduleDraft.weekdays
                                                .contains(day),
                                            onSelected: (selected) {
                                              setLocalState(() {
                                                if (selected) {
                                                  scheduleDraft.weekdays.add(
                                                    day,
                                                  );
                                                } else if (scheduleDraft
                                                        .weekdays
                                                        .length >
                                                    1) {
                                                  scheduleDraft.weekdays.remove(
                                                    day,
                                                  );
                                                }
                                              });
                                            },
                                          );
                                        }),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (scheduleDraft.presetId ==
                                      'monthly') ...<Widget>[
                                    DropdownButtonFormField<int>(
                                      initialValue: scheduleDraft.monthDay,
                                      decoration: const InputDecoration(
                                        labelText: 'Day of month',
                                      ),
                                      items:
                                          List<DropdownMenuItem<int>>.generate(
                                            31,
                                            (index) => DropdownMenuItem<int>(
                                              value: index + 1,
                                              child: Text('Day ${index + 1}'),
                                            ),
                                          ),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          scheduleDraft.monthDay = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Schedule',
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final preset = _taskSchedulePresetForId(
                                          scheduleDraft.presetId,
                                        );
                                        return Row(
                                          children: <Widget>[
                                            Icon(preset.icon, color: _accent),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Text(
                                                    scheduleDraft.summary,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    preset.description,
                                                    style: TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }

                          return Column(
                            children: <Widget>[
                              _buildConnectionIdSelector(
                                triggerType: selectedTriggerType,
                                selectedConnectionId: selectedConnectionId,
                                fallbackController: connectionIdController,
                                setLocalState: setLocalState,
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
                      ValueListenableBuilder<TaskDeliveryTarget?>(
                        valueListenable: selectedDeliveryTarget,
                        builder: (context, deliveryTarget, _) {
                          final color = deliveryTarget == null
                              ? _textSecondary
                              : _taskDeliveryPlatformColor(
                                  deliveryTarget.platform,
                                );
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final picked = await _pickTaskDeliveryTarget(
                                context,
                                controller: controller,
                                agentId: selectedAgentId,
                                selected: deliveryTarget,
                              );
                              if (picked == null) return;
                              selectedDeliveryTarget.value =
                                  picked.platform.isEmpty ? null : picked;
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Result Delivery',
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      deliveryTarget == null
                                          ? Icons.auto_mode_rounded
                                          : _taskDeliveryPlatformIcon(
                                              deliveryTarget.platform,
                                            ),
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          deliveryTarget == null
                                              ? 'Use default channel'
                                              : deliveryTarget.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          deliveryTarget == null
                                              ? 'AI-created and unspecified tasks use the current default.'
                                              : '${deliveryTarget.platformLabel} · ${deliveryTarget.to}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (deliveryTarget != null)
                                    IconButton(
                                      tooltip: 'Use default channel',
                                      onPressed: () =>
                                          selectedDeliveryTarget.value = null,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.unfold_more_rounded,
                                      color: _textSecondary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedModel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Model Override',
                        ),
                        items: _taskModelOverrideItems(
                          selectedModel: selectedModel,
                          models: controller.supportedModels,
                        ),
                        onChanged: (value) => setLocalState(
                          () => selectedModel = value ?? 'auto',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _border.withValues(alpha: 0.8),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.pause_circle_outline,
                                  size: 18,
                                  color: _textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Loop execution',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              value: loopPaused,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Pause task loop'),
                              subtitle: const Text(
                                'Skip this task before it calls the model.',
                              ),
                              onChanged: (value) =>
                                  setLocalState(() => loopPaused = value),
                            ),
                          ],
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
                          onChanged: (value) => setLocalState(() {
                            selectedAgentId = value;
                            selectedDeliveryTarget.value = null;
                          }),
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
                      triggerConfig['mode'] = scheduleDraft.mode;
                      if (scheduleDraft.mode == 'recurring') {
                        scheduleDraft.customCronExpression =
                            customCronController.text.trim();
                        final cronExpression = scheduleDraft.cronExpression
                            .trim();
                        if (cronExpression.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please choose a schedule.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (scheduleDraft.presetId == 'custom' &&
                            !_looksLikeCronExpression(cronExpression)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Custom Cron must have 5 fields.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        triggerConfig['cronExpression'] = cronExpression;
                      } else {
                        if (runAt.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter when the task should run.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        triggerConfig['runAt'] = runAt;
                      }
                    } else {
                      final parsedConnectionId =
                          selectedConnectionId.value ??
                          int.tryParse(connectionIdController.text.trim());
                      if (parsedConnectionId == null ||
                          parsedConnectionId <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select an account or enter a valid connection ID.',
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
                    final taskConfig = <String, dynamic>{
                      ...?task?.taskConfig,
                      'loopPaused': loopPaused,
                    };
                    taskConfig.remove('loopBudget');
                    taskConfig.remove('loop_paused');
                    final deliveryTarget = selectedDeliveryTarget.value;
                    if (deliveryTarget == null) {
                      taskConfig.remove('notifyPlatform');
                      taskConfig.remove('notifyTo');
                    } else {
                      taskConfig['notifyPlatform'] = deliveryTarget.platform;
                      taskConfig['notifyTo'] = deliveryTarget.to;
                    }
                    await controller.saveTask(
                      id: task?.id,
                      name: nameController.text.trim(),
                      triggerType: selectedTriggerType,
                      triggerConfig: triggerConfig,
                      prompt: promptController.text.trim(),
                      taskConfig: taskConfig,
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
