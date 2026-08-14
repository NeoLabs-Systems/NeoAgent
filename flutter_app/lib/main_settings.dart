part of 'main.dart';

enum _LeaveAction { save, discard, cancel }

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final NeoAgentController controller;
  final bool embedded;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsSection {
  const _SettingsSection(
    this.title,
    this.label,
    this.icon,
    this.keywords, {
    this.requiresDesktop = false,
  });

  final String title;
  final String label;
  final IconData icon;
  final List<String> keywords;
  final bool requiresDesktop;
}

const _overviewSettingsSection = _SettingsSection(
  'overview',
  'Overview',
  Icons.dashboard_outlined,
  <String>['overview', 'summary', 'onboarding', 'platform', 'providers'],
);

const _workspaceSettingsSection = _SettingsSection(
  'workspace',
  'Workspace',
  Icons.workspaces_outline,
  <String>[
    'workspace',
    'browser',
    'cli',
    'desktop',
    'files',
    'terminal',
    'computer',
  ],
);

const _behaviorSettingsSection = _SettingsSection(
  'behavior',
  'Behavior',
  Icons.psychology_outlined,
  <String>[
    'behavior',
    'persona',
    'social intelligence',
    'turn taking',
    'groups',
    'memory',
    'norms',
    'theory of mind',
    'delivery',
  ],
);

const _modelsSettingsSection =
    _SettingsSection('models', 'Models & routing', Icons.hub_outlined, <String>[
      'models',
      'providers',
      'routing',
      'fallback',
      'chat',
      'sub-agent',
      'subagent',
      'smart selector',
    ]);

const _socialReachSettingsSection = _SettingsSection(
  'social reach',
  'Social reach',
  Icons.public_outlined,
  <String>[
    'social',
    'reach',
    'web',
    'rss',
    'github',
    'youtube',
    'linkedin',
    'xueqiu',
    'twitter',
    'reddit',
    'instagram',
    'facebook',
    'cookies',
  ],
);

const _voiceSettingsSection = _SettingsSection(
  'voice',
  'Voice',
  Icons.mic_none_outlined,
  <String>['voice', 'speech', 'tts', 'stt', 'live'],
);

const _desktopSettingsSection = _SettingsSection(
  'desktop',
  'Desktop',
  Icons.desktop_windows_outlined,
  <String>['desktop', 'local app', 'tray', 'hotkey'],
  requiresDesktop: true,
);

const _diagnosticsSettingsSection = _SettingsSection(
  'diagnostics',
  'Diagnostics',
  Icons.monitor_heart_outlined,
  <String>['diagnostics', 'logs', 'token', 'usage', 'debug', 'health'],
);

const _securitySettingsSection = _SettingsSection(
  'security',
  'Permissions',
  Icons.admin_panel_settings_outlined,
  <String>[
    'security',
    'tool',
    'permission',
    'allowlist',
    'shell',
    'android',
    'approval',
    'policy',
  ],
);

const List<_SettingsSection> _settingsSearchSections = <_SettingsSection>[
  _overviewSettingsSection,
  _modelsSettingsSection,
  _workspaceSettingsSection,
  _behaviorSettingsSection,
  _socialReachSettingsSection,
  _voiceSettingsSection,
  _desktopSettingsSection,
  _securitySettingsSection,
  _diagnosticsSettingsSection,
];

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _searchController;
  _SettingsSection _selectedSettingsSection = _overviewSettingsSection;
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _fallbackModel;
  late String _defaultSpeechModel;
  late String _voiceSttProvider;
  late String _voiceSttModel;
  late String _voiceTtsProvider;
  late String _voiceTtsModel;
  late String _voiceTtsVoice;
  late String _voiceMediaMode;
  late String _voiceInputMode;
  final Map<String, bool> _providerEnabled = <String, bool>{};
  final Map<String, TextEditingController> _providerBaseUrlControllers =
      <String, TextEditingController>{};
  late final TextEditingController _behaviorNotesController;
  late bool _behaviorEnabled;
  late String _behaviorParticipationMode;
  late double _behaviorMinimumNeedScore;
  late double _behaviorBatchWindowMs;
  late String _behaviorDecisionModelId;
  late String _behaviorDeliveryStyle;
  late bool _behaviorTheoryOfMindEnabled;
  late bool _behaviorSocialMemoryEnabled;
  late bool _behaviorNormsEnabled;
  late bool _behaviorObservabilityEnabled;

  bool _hasUnsavedChanges = false;

  // Inline runtime test state — ephemeral, not stored in controller.
  bool _cliTestRunning = false;
  Map<String, dynamic>? _cliTestResult;
  bool _socialReachRefreshing = false;
  String? _socialReachBusyPlatform;
  Map<String, dynamic>? _socialReachActionResult;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _behaviorNotesController = TextEditingController();
    _hydrate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _behaviorNotesController.dispose();
    for (final controller in _providerBaseUrlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings != widget.controller.settings ||
        oldWidget.controller.behaviorConfig !=
            widget.controller.behaviorConfig ||
        oldWidget.controller.memoryOverview !=
            widget.controller.memoryOverview ||
        oldWidget.controller.aiProviders != widget.controller.aiProviders ||
        oldWidget.controller.supportedModels !=
            widget.controller.supportedModels) {
      _hydrate();
    }
  }

  void _hydrate() {
    final controller = widget.controller;
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toSet();
    _smarterSelector = controller.smarterSelector;
    // Only keep ids that are still available -- a model the admin has since
    // disabled (or whose provider lost its credentials) must not survive
    // hydration, or saving would silently re-persist it into the pool.
    _enabledModels = controller.enabledModelIds
        .where((id) => availableModels.contains(id))
        .toSet();
    if (_enabledModels.isEmpty && availableModels.isNotEmpty) {
      _enabledModels = availableModels;
    }
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _fallbackModel = controller.fallbackModel;
    _defaultSpeechModel = controller.defaultSpeechModel;
    _voiceSttProvider = controller.voiceSttProvider;
    _voiceSttModel = controller.voiceSttModel;
    _voiceTtsProvider = controller.voiceTtsProvider;
    _voiceTtsModel = controller.voiceTtsModel;
    _voiceTtsVoice = controller.voiceTtsVoice;
    _voiceMediaMode = controller.voiceMediaMode;
    _voiceInputMode = controller.voiceInputMode;
    final behavior = controller.behaviorConfig;
    final modules = behavior['modules'] is Map
        ? Map<String, dynamic>.from(behavior['modules'] as Map)
        : const <String, dynamic>{};
    bool moduleEnabled(String id) {
      final module = modules[id];
      return module is! Map || module['enabled'] != false;
    }

    _behaviorEnabled = behavior['enabled'] != false;
    _behaviorParticipationMode =
        <String>{
          'automatic',
          'mention_only',
          'always',
        }.contains(behavior['participationMode']?.toString())
        ? behavior['participationMode'].toString()
        : 'automatic';
    _behaviorMinimumNeedScore =
        ((behavior['minimumNeedScore'] as num?)?.toDouble() ?? 0.72)
            .clamp(0.0, 1.0)
            .toDouble();
    _behaviorBatchWindowMs =
        ((behavior['batchWindowMs'] as num?)?.toDouble() ?? 900)
            .clamp(0.0, 5000.0)
            .toDouble();
    _behaviorDecisionModelId =
        behavior['decisionModelId']?.toString().trim() ?? '';
    _behaviorDeliveryStyle = behavior['deliveryStyle'] == 'single'
        ? 'single'
        : 'natural_bubbles';
    _behaviorTheoryOfMindEnabled = moduleEnabled('theory_of_mind');
    _behaviorSocialMemoryEnabled = moduleEnabled('social_memory');
    _behaviorNormsEnabled = moduleEnabled('norms');
    _behaviorObservabilityEnabled = moduleEnabled('social_observability');
    final behaviorNotes = controller.memoryOverview.assistantBehaviorNotes;
    if (_behaviorNotesController.text != behaviorNotes) {
      _behaviorNotesController.text = behaviorNotes;
    }
    final providerConfigs = controller.aiProviderConfigs;
    final providerIds = <String>{
      ...providerConfigs.keys,
      ...controller.aiProviders.map((provider) => provider.id),
    };

    for (final providerId in providerIds) {
      final config =
          providerConfigs[providerId] ?? AiProviderConfig.empty(providerId);
      _providerEnabled[providerId] = config.enabled;
      _syncTextController(
        _providerBaseUrlControllers,
        providerId,
        config.baseUrl,
      );
    }

    _pruneControllers(_providerBaseUrlControllers, providerIds);
    _providerEnabled.removeWhere((id, _) => !providerIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final searchQuery = _searchController.text.trim().toLowerCase();
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final List<_ModelPickerOption> modelChoices = _modelPickerOptions(
      routingModels,
      allowAuto: true,
    );
    final enabledSmartModels = _enabledModels
        .where((id) => routingModels.any((model) => model.id == id))
        .length;
    final visibleSearchSections = _settingsSearchSections
        .where((section) => !section.requiresDesktop || _supportsDesktopShell)
        .toSet();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final action = await _showLeaveDialog(context);
        if (!context.mounted) return;
        if (action == _LeaveAction.save) {
          await _doSave();
          if (context.mounted) Navigator.of(context).pop();
        } else if (action == _LeaveAction.discard) {
          _hydrate();
          setState(() => _hasUnsavedChanges = false);
          Navigator.of(context).pop();
        }
        // cancel: do nothing
      },
      child: ListView(
        padding: widget.embedded ? EdgeInsets.zero : _pagePadding(context),
        children: <Widget>[
          if (!widget.embedded)
            _PageTitle(
              title: 'Settings',
              subtitle: 'Workspace, models, and diagnostics controls.',
              trailing: _settingsSaveButton(controller),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'General settings',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose a category or search across all settings.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _settingsSaveButton(controller),
                ],
              ),
            ),
          if (controller.errorMessage != null) ...<Widget>[
            _InlineError(message: controller.errorMessage!),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search settings',
              hintText: 'Models, browser, voice, diagnostics...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsCategoryPicker(visibleSearchSections),
          const SizedBox(height: 16),
          if (_showsSettingsSection(
            searchQuery,
            _overviewSettingsSection,
          )) ...<Widget>[
            _buildSettingsOverview(controller, availableModels.length),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _behaviorSettingsSection,
          )) ...<Widget>[
            _buildBehaviorSection(controller, routingModels),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _workspaceSettingsSection,
          )) ...<Widget>[
            _buildWorkspaceSection(controller),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _socialReachSettingsSection,
          )) ...<Widget>[
            _buildSocialReachSection(controller),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _modelsSettingsSection,
          )) ...<Widget>[
            _buildModelsSection(
              context: context,
              controller: controller,
              modelChoices: modelChoices,
              routingModels: routingModels,
              availableModels: availableModels,
              enabledSmartModels: enabledSmartModels,
            ),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _voiceSettingsSection,
          )) ...<Widget>[
            _buildVoiceSection(
              controller: controller,
              modelChoices: modelChoices,
              routingModels: routingModels,
            ),
            const SizedBox(height: 16),
          ],
          if (visibleSearchSections.contains(_desktopSettingsSection) &&
              _showsSettingsSection(
                searchQuery,
                _desktopSettingsSection,
              )) ...<Widget>[
            _buildDesktopSection(controller),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _securitySettingsSection,
          )) ...<Widget>[
            _buildSecuritySection(context, controller),
            const SizedBox(height: 16),
          ],
          if (_showsSettingsSection(
            searchQuery,
            _diagnosticsSettingsSection,
          )) ...<Widget>[_buildDiagnosticsSection(controller)],
          if (_noSettingsMatches(
            searchQuery,
            visibleSearchSections,
          )) ...<Widget>[
            const _EmptyCard(
              title: 'No matching settings',
              subtitle: 'Try a broader search like models, browser, or voice.',
            ),
          ],
        ],
      ),
    );
  }

  bool _matchesSettingsSection(String query, _SettingsSection section) {
    if (query.isEmpty) {
      return true;
    }
    final haystack = <String>[
      section.title,
      ...section.keywords,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  bool _showsSettingsSection(String query, _SettingsSection section) {
    if (query.isNotEmpty) {
      return _matchesSettingsSection(query, section);
    }
    return _selectedSettingsSection == section;
  }

  Widget _buildSettingsCategoryPicker(Set<_SettingsSection> visibleSections) {
    final sections = _settingsSearchSections
        .where(visibleSections.contains)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return DropdownButtonFormField<_SettingsSection>(
            key: ValueKey<_SettingsSection>(_selectedSettingsSection),
            initialValue: _selectedSettingsSection,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: sections
                .map(
                  (section) => DropdownMenuItem<_SettingsSection>(
                    value: section,
                    child: Row(
                      children: <Widget>[
                        Icon(section.icon, size: 18),
                        const SizedBox(width: 10),
                        Text(section.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (section) {
              if (section == null) return;
              _searchController.clear();
              setState(() => _selectedSettingsSection = section);
            },
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sections
              .map(
                (section) => ChoiceChip(
                  avatar: Icon(section.icon, size: 17),
                  label: Text(section.label),
                  selected: _selectedSettingsSection == section,
                  onSelected: (_) {
                    _searchController.clear();
                    setState(() => _selectedSettingsSection = section);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  bool _noSettingsMatches(
    String query,
    Iterable<_SettingsSection> visibleSections,
  ) {
    if (query.isEmpty) {
      return false;
    }
    return !visibleSections.any(
      (section) => _matchesSettingsSection(query, section),
    );
  }

  Future<void> _doSave() async {
    final controller = widget.controller;
    await controller.saveSettings(
      smarterSelector: _smarterSelector,
      enabledModels: _enabledModels.toList(),
      defaultChatModel: _defaultChatModel,
      defaultSubagentModel: _defaultSubagentModel,
      fallbackModel: _fallbackModel,
      defaultSpeechModel: _defaultSpeechModel,
      voiceSttProvider: _voiceSttProvider,
      voiceSttModel: _voiceSttModel,
      voiceTtsProvider: _voiceTtsProvider,
      voiceTtsModel: _voiceTtsModel,
      voiceTtsVoice: _voiceTtsVoice,
      voiceMediaMode: _voiceMediaMode,
      voiceInputMode: _voiceInputMode,
      aiProviderConfigs: _buildProviderPayload(),
    );
    if (controller.errorMessage != null) return;
    final existingModules = controller.behaviorConfig['modules'] is Map
        ? Map<String, dynamic>.from(controller.behaviorConfig['modules'] as Map)
        : <String, dynamic>{};
    existingModules.addAll(<String, dynamic>{
      'theory_of_mind': <String, dynamic>{
        'enabled': _behaviorTheoryOfMindEnabled,
      },
      'social_memory': <String, dynamic>{
        'enabled': _behaviorSocialMemoryEnabled,
      },
      'norms': <String, dynamic>{'enabled': _behaviorNormsEnabled},
      'social_observability': <String, dynamic>{
        'enabled': _behaviorObservabilityEnabled,
      },
    });
    await controller.saveBehaviorConfig(<String, dynamic>{
      ...controller.behaviorConfig,
      'enabled': _behaviorEnabled,
      'participationMode': _behaviorParticipationMode,
      'minimumNeedScore': _behaviorMinimumNeedScore,
      'batchWindowMs': _behaviorBatchWindowMs.round(),
      'decisionModelId': _behaviorDecisionModelId.isEmpty
          ? null
          : _behaviorDecisionModelId,
      'deliveryStyle': _behaviorDeliveryStyle,
      'modules': existingModules,
    });
    if (controller.errorMessage != null) return;
    if (_behaviorNotesController.text !=
        controller.memoryOverview.assistantBehaviorNotes) {
      await controller.updateAssistantBehaviorNotes(
        _behaviorNotesController.text,
      );
      if (controller.errorMessage != null) return;
    }
    if (mounted) setState(() => _hasUnsavedChanges = false);
  }

  Widget _settingsSaveButton(NeoAgentController controller) {
    final button = FilledButton.icon(
      onPressed: controller.isSavingSettings ? null : _doSave,
      style: FilledButton.styleFrom(backgroundColor: _accent),
      icon: controller.isSavingSettings
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(Icons.save_outlined),
      label: Text('Save'),
    );
    if (!_hasUnsavedChanges) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Unsaved changes',
          style: TextStyle(color: Colors.orange, fontSize: 12),
        ),
        const SizedBox(height: 4),
        button,
      ],
    );
  }

  Widget _buildSettingsOverview(
    NeoAgentController controller,
    int availableModelCount,
  ) {
    final platformLabel = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Overview'),
            const SizedBox(height: 10),
            Text(
              'Configure workspace behavior and model defaults.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            if (!controller.setupComplete &&
                controller.setupOpenSections.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Complete setup',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'NeoAgent is ready. Add these optional capabilities whenever you want:',
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final section in controller.setupOpenSections)
                          Chip(
                            avatar: const Icon(Icons.circle_outlined, size: 15),
                            label: Text(
                              section
                                  .replaceAll('-', ' ')
                                  .split(' ')
                                  .where((word) => word.isNotEmpty)
                                  .map(
                                    (word) =>
                                        '${word[0].toUpperCase()}${word.substring(1)}',
                                  )
                                  .join(' '),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.devices_outlined,
                  label:
                      'Platform ${platformLabel[0].toUpperCase()}${platformLabel.substring(1)}',
                ),
                _MetaPill(
                  icon: Icons.memory_outlined,
                  label: '$availableModelCount models ready',
                ),
                _MetaPill(
                  icon: Icons.hub_outlined,
                  label: '${controller.aiProviders.length} providers',
                ),
                _MetaPill(
                  icon: Icons.auto_awesome_outlined,
                  label: _smarterSelector
                      ? 'Smart selector on'
                      : 'Manual routing',
                ),
                if (_supportsDesktopShell)
                  const _MetaPill(
                    icon: Icons.desktop_windows_outlined,
                    label: 'Desktop app controls available',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: controller.reopenOnboarding,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Redo onboarding'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorSection(
    NeoAgentController controller,
    List<ModelMeta> routingModels,
  ) {
    final modelIds = <String>{
      if (_behaviorDecisionModelId.isNotEmpty) _behaviorDecisionModelId,
      ...routingModels.map((model) => model.id),
    }.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Behavior Modules'),
            const SizedBox(height: 10),
            Text(
              'One runtime controls persona, group turn-taking, room memory, norms, Theory of Mind, and delivery.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable behavior modules'),
              subtitle: const Text(
                'Direct messages remain responsive. Allowlisted groups use the participation mode below.',
              ),
              value: _behaviorEnabled,
              onChanged: (value) => setState(() {
                _behaviorEnabled = value;
                _hasUnsavedChanges = true;
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _behaviorParticipationMode,
              decoration: const InputDecoration(
                labelText: 'Default group participation',
                helperText:
                    'Automatic reads the room and normally holds back. Mention-only makes no decision call until directly addressed.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'automatic',
                  child: Text('Automatic, reserved'),
                ),
                DropdownMenuItem(
                  value: 'mention_only',
                  child: Text('Mention or reply only'),
                ),
                DropdownMenuItem(value: 'always', child: Text('Always engage')),
              ],
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _behaviorParticipationMode = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
            const SizedBox(height: 18),
            Text(
              'Minimum contribution value: ${_behaviorMinimumNeedScore.toStringAsFixed(2)}',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: _behaviorMinimumNeedScore,
              min: 0,
              max: 1,
              divisions: 20,
              label: _behaviorMinimumNeedScore.toStringAsFixed(2),
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorMinimumNeedScore = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            Text(
              'Higher values make NeoAgent more selective in groups.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              'Room batch window: ${_behaviorBatchWindowMs.round()} ms',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: _behaviorBatchWindowMs,
              min: 0,
              max: 5000,
              divisions: 20,
              label: '${_behaviorBatchWindowMs.round()} ms',
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorBatchWindowMs = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _behaviorDecisionModelId,
              decoration: const InputDecoration(
                labelText: 'Turn-taking model',
                helperText:
                    'Automatic selects a fast model through the normal model catalog.',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(
                  value: '',
                  child: Text('Automatic (fast)'),
                ),
                ...modelIds.map(
                  (id) => DropdownMenuItem(value: id, child: Text(id)),
                ),
              ],
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _behaviorDecisionModelId = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _behaviorDeliveryStyle,
              decoration: const InputDecoration(
                labelText: 'Messaging delivery',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'natural_bubbles',
                  child: Text('Natural bubbles'),
                ),
                DropdownMenuItem(
                  value: 'single',
                  child: Text('Single message'),
                ),
              ],
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _behaviorDeliveryStyle = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theory of Mind refinement'),
              value: _behaviorTheoryOfMindEnabled,
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorTheoryOfMindEnabled = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Channel-scoped social memory'),
              value: _behaviorSocialMemoryEnabled,
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorSocialMemoryEnabled = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Learn room norms'),
              value: _behaviorNormsEnabled,
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorNormsEnabled = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Social observability'),
              value: _behaviorObservabilityEnabled,
              onChanged: !_behaviorEnabled
                  ? null
                  : (value) => setState(() {
                      _behaviorObservabilityEnabled = value;
                      _hasUnsavedChanges = true;
                    }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _behaviorNotesController,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {
                _hasUnsavedChanges = true;
              }),
              decoration: const InputDecoration(
                labelText: 'Persona behavior notes',
                helperText:
                    'Durable instructions for voice and interaction style. Safety and execution rules still take priority.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceSection(NeoAgentController controller) {
    final state = controller.computerRuntime['state']?.toString() ?? 'stopped';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Computer workspace'),
            const SizedBox(height: 10),
            Text(
              'Browser, Linux desktop, files, terminal, and Python share one persistent cloud computer.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _DotStatus(
                  label: state.replaceAll('_', ' '),
                  color:
                      state == 'ready' ||
                          state == 'user_control' ||
                          state == 'agent_control' ||
                          state == 'teaching'
                      ? _success
                      : state == 'error'
                      ? _danger
                      : _warning,
                ),
                FilledButton.icon(
                  onPressed: controller.isRunningDeviceAction
                      ? null
                      : controller.startComputerRuntime,
                  icon: const Icon(Icons.computer_outlined),
                  label: const Text('Open computer'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isRunningDeviceAction
                      ? null
                      : controller.stopComputerRuntime,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'The runtime is a lightweight Debian Linux desktop with Chromium, PCManFM, Mousepad, LXTerminal, Python, Git, and standard command-line tools. Its capacity is managed by the NeoAgent host.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const Divider(height: 32),
            _buildInlineTestRow(
              label: 'Computer shell',
              running: _cliTestRunning,
              result: _cliTestResult,
              note:
                  'Commands run in the same persistent computer used by the visible desktop.',
              onTest: () async {
                setState(() {
                  _cliTestRunning = true;
                  _cliTestResult = null;
                });
                try {
                  final result = await controller.testCliRuntime();
                  if (mounted) setState(() => _cliTestResult = result);
                } catch (error) {
                  if (mounted) {
                    setState(() {
                      _cliTestResult = <String, dynamic>{
                        'passed': false,
                        'detail': error.toString(),
                      };
                    });
                  }
                } finally {
                  if (mounted) setState(() => _cliTestRunning = false);
                }
              },
            ),
            const Divider(height: 32),
            _SettingToggle(
              title: 'Smart model selection',
              subtitle:
                  'Automatically choose the best enabled model for each task type.',
              value: _smarterSelector,
              onChanged: (value) => setState(() {
                _smarterSelector = value;
                _hasUnsavedChanges = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _socialReachPlatforms(
    NeoAgentController controller,
  ) {
    final raw = controller.socialReachStatus['platforms'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Color _socialReachStatusColor(Map<String, dynamic> platform) {
    final status = platform['status']?.toString().toLowerCase() ?? '';
    if (platform['ready'] == true || status == 'ok') return _success;
    if (status == 'warn') return _warning;
    if (status == 'error') return _danger;
    return _textSecondary;
  }

  Widget _buildSocialReachSection(NeoAgentController controller) {
    final platforms = _socialReachPlatforms(controller);
    final ready = platforms
        .where((item) => item['ready'] == true || item['status'] == 'ok')
        .length;
    final cookieSetup = platforms
        .where((item) => item['setupKind'] == 'cookies')
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: _SectionTitle('Social Reach')),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _socialReachRefreshing
                      ? null
                      : () async {
                          setState(() {
                            _socialReachRefreshing = true;
                            _socialReachActionResult = null;
                          });
                          try {
                            await controller.refreshSocialReachStatus();
                          } catch (e) {
                            if (mounted) {
                              setState(
                                () => _socialReachActionResult =
                                    <String, dynamic>{'error': e.toString()},
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _socialReachRefreshing = false);
                            }
                          }
                        },
                  icon: _socialReachRefreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Social sources agents can read directly, including feeds, repositories, Reddit, X, videos, and cookie-backed market data.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.check_circle_outline,
                  label: '$ready ready',
                  color: _success,
                ),
                _MetaPill(
                  icon: Icons.play_circle_outline,
                  label: 'Video links',
                  color: _info,
                ),
                if (cookieSetup > 0)
                  _MetaPill(
                    icon: Icons.computer_outlined,
                    label: 'Cookie setup',
                    color: _warning,
                  ),
              ],
            ),
            if (_socialReachActionResult != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (_socialReachActionResult!['error'] == null
                              ? _success
                              : _danger)
                          .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (_socialReachActionResult!['error'] == null
                                ? _success
                                : _danger)
                            .withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  _socialReachActionResult!['error']?.toString() ??
                      'Social Reach updated.',
                  style: TextStyle(
                    color: _socialReachActionResult!['error'] == null
                        ? _success
                        : _danger,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (platforms.isEmpty)
              Text(
                'Status is not loaded yet.',
                style: TextStyle(color: _textSecondary),
              )
            else
              ...platforms.map(
                (platform) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildSocialReachPlatformRow(controller, platform),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialReachPlatformRow(
    NeoAgentController controller,
    Map<String, dynamic> platform,
  ) {
    final id = platform['platform']?.toString() ?? '';
    final label = platform['label']?.toString() ?? id;
    final setupKind = platform['setupKind']?.toString() ?? '';
    final status = platform['status']?.toString() ?? 'off';
    final message = platform['message']?.toString() ?? '';
    final cookie = platform['cookie'] is Map
        ? Map<String, dynamic>.from(platform['cookie'] as Map)
        : const <String, dynamic>{};
    final busy = _socialReachBusyPlatform == id;
    final canImport = setupKind == 'cookies';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(
                label: status,
                color: _socialReachStatusColor(platform),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: _textSecondary, height: 1.35)),
          if (cookie.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              cookie['configured'] == true
                  ? '${cookie['count'] ?? 0} cookies imported'
                  : 'Cookies not configured',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
          if (canImport) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => _runSocialReachAction(
                          controller,
                          id,
                          () => controller.importSocialReachCookies(id),
                        ),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.computer_outlined, size: 18),
                  label: const Text('Import from computer'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _runSocialReachAction(
                          controller,
                          id,
                          () => controller.clearSocialReachCookies(id),
                        ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runSocialReachAction(
    NeoAgentController controller,
    String platform,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() {
      _socialReachBusyPlatform = platform;
      _socialReachActionResult = null;
    });
    try {
      final result = await action();
      if (mounted) {
        setState(() => _socialReachActionResult = result);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _socialReachActionResult = <String, dynamic>{
            'error': e.toString(),
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _socialReachBusyPlatform = null);
      }
    }
  }

  Widget _buildModelsSection({
    required BuildContext context,
    required NeoAgentController controller,
    required List<_ModelPickerOption> modelChoices,
    required List<ModelMeta> routingModels,
    required List<ModelMeta> availableModels,
    required int enabledSmartModels,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Models'),
            const SizedBox(height: 10),
            Text(
              'Choose defaults for chat, agents, fallback behavior, and smart routing.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Default Routing',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (routingModels.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 940;
                  final cardWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Chat',
                          icon: Icons.chat_bubble_outline,
                          value: _ensureModelValue(
                            _defaultChatModel,
                            routingModels,
                            allowAuto: true,
                            preserveUnknown: true,
                          ),
                          options: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _defaultChatModel = value;
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Sub-agent',
                          icon: Icons.bolt_outlined,
                          value: _ensureModelValue(
                            _defaultSubagentModel,
                            routingModels,
                            allowAuto: true,
                            preserveUnknown: true,
                          ),
                          options: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _defaultSubagentModel = value;
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Fallback',
                          icon: Icons.shield_outlined,
                          value: _ensureModelValue(
                            _fallbackModel,
                            routingModels,
                            allowAuto: false,
                          ),
                          options: _modelPickerOptions(routingModels),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _fallbackModel = value;
                                _hasUnsavedChanges = true;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            const Divider(height: 32),
            Text(
              'Smart Selector Pool',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The models the Smart Selector routes between automatically.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            _SmartPoolSummary(
              allModels: controller.supportedModels,
              selectedIds: _enabledModels,
              onManage: () async {
                final result = await showGeneralDialog<Set<String>>(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'Dismiss',
                  barrierColor: Colors.black.withValues(alpha: 0.55),
                  transitionDuration: const Duration(milliseconds: 220),
                  transitionBuilder: (ctx, anim, _, child) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOut,
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  pageBuilder: (ctx, _, __) => _SmartPoolDialog(
                    models: controller.supportedModels,
                    selectedIds: _enabledModels,
                  ),
                );
                if (result != null) {
                  setState(() {
                    _enabledModels = result;
                    _hasUnsavedChanges = true;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection({
    required NeoAgentController controller,
    required List<_ModelPickerOption> modelChoices,
    required List<ModelMeta> routingModels,
  }) {
    final capabilityProviders = _jsonList(
      controller.voiceCapabilities['providers'],
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    final sttProviders = capabilityProviders
        .where((item) => item['boundedStt'] is Map)
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final ttsProviders = capabilityProviders
        .where((item) => item['streamingTts'] is Map)
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    Map<String, dynamic> capabilityFor(String id) =>
        capabilityProviders.firstWhere(
          (item) => item['id']?.toString() == id,
          orElse: () => <String, dynamic>{},
        );
    final mediaModes = _jsonStringList(
      controller.voiceCapabilities['mediaModes'],
    );
    final inputModes = _jsonStringList(
      controller.voiceCapabilities['inputModes'],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Voice'),
            const SizedBox(height: 10),
            Text(
              'Defaults for speech processing and live voice.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Speech Processing',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 940;
                final cardWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Speech Model',
                        icon: Icons.record_voice_over_outlined,
                        value: _ensureModelValue(
                          _defaultSpeechModel,
                          routingModels,
                          allowAuto: true,
                          preserveUnknown: true,
                        ),
                        options: modelChoices,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _defaultSpeechModel = value;
                              _hasUnsavedChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Used for the backend LLM that processes voice assistant and other speech-originated turns. This does not change the speech synthesis voice.',
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const Divider(height: 32),
            Text(
              'Voice Media',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 940;
                final cardWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Speech-to-text provider',
                        icon: Icons.hearing_outlined,
                        value: _voiceSttProvider,
                        options: _simplePickerOptions(
                          sttProviders.isEmpty
                              ? <String>[_voiceSttProvider]
                              : sttProviders,
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceSttProvider = value;
                            final capability = capabilityFor(value);
                            final streaming = _jsonMap(
                              capability['streamingStt'],
                            );
                            final bounded = _jsonMap(capability['boundedStt']);
                            _voiceSttModel =
                                streaming['model']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? streaming['model'].toString()
                                : bounded['model']?.toString() ??
                                      _voiceSttModel;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Text-to-speech provider',
                        icon: Icons.record_voice_over_outlined,
                        value: _voiceTtsProvider,
                        options: _simplePickerOptions(
                          ttsProviders.isEmpty
                              ? <String>[_voiceTtsProvider]
                              : ttsProviders,
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceTtsProvider = value;
                            final tts = _jsonMap(
                              capabilityFor(value)['streamingTts'],
                            );
                            _voiceTtsModel =
                                tts['model']?.toString() ?? _voiceTtsModel;
                            _voiceTtsVoice =
                                tts['voice']?.toString() ?? _voiceTtsVoice;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Media mode',
                        icon: Icons.call_outlined,
                        value: _voiceMediaMode,
                        options: _simplePickerOptions(
                          mediaModes.isEmpty
                              ? <String>[_voiceMediaMode]
                              : mediaModes,
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceMediaMode = value;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Input mode',
                        icon: Icons.mic_outlined,
                        value: _voiceInputMode,
                        options: _simplePickerOptions(
                          inputModes.isEmpty
                              ? <String>[_voiceInputMode]
                              : inputModes,
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceInputMode = value;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Auto uses a provider-native realtime shell only when the selected speech providers match and advertise duplex support. Every task still runs through the normal NeoAgent chat runtime. Composed always uses streaming transcription followed by the selected streaming voice.',
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'STT: $_voiceSttModel · TTS: $_voiceTtsModel${_voiceTtsVoice.isEmpty ? '' : ' · $_voiceTtsVoice'}',
              style: TextStyle(color: _textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Desktop app'),
            const SizedBox(height: 10),
            Text(
              'Local preferences for the NeoAgent application. Computer control always runs through the unified cloud computer.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: controller.desktopAskOnClose,
              contentPadding: EdgeInsets.zero,
              title: const Text('Ask before closing to background'),
              subtitle: Text(
                'Prompt before NeoAgent stays resident in the system tray.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: (value) => controller.setDesktopClosePreference(
                askOnClose: value,
                keepRunningOnClose: controller.desktopKeepRunningOnClose,
              ),
            ),
            SwitchListTile.adaptive(
              value: controller.desktopAssistantHotkeyEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Reserve assistant hotkey'),
              subtitle: Text(
                'Register $_desktopAssistantHotkeyLabel for the assistant summon flow.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.setDesktopAssistantHotkeyEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    NeoAgentController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Security'),
            const SizedBox(height: 10),
            Text(
              'Per-tool permission policies, approval gates, and process isolation for shell execution.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.checklist_outlined, color: _accentAlt),
              title: const Text('Tool Permissions'),
              subtitle: Text(
                'Set block / ask / allow per tool category, or pick a global mode.',
                style: TextStyle(color: _textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MainSecurity(controller: controller),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _SectionTitle('Diagnostics'),
                const SizedBox(width: 8),
                Icon(Icons.info_outline, size: 16, color: _textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Usage and health signals that help explain current runtime behavior without digging through logs first.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (controller.tokenUsage == null)
              Text(
                'Token usage unavailable on this server version.',
                style: TextStyle(color: _textSecondary),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total: ${controller.tokenUsage!.totalTokensLabel} tokens across ${controller.tokenUsage!.totalRunsLabel} runs',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last 7 days: ${controller.tokenUsage!.last7DaysTokensLabel} tokens in ${controller.tokenUsage!.last7DaysRunsLabel} runs',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Avg/run: ${controller.tokenUsage!.avgTokensPerRunLabel} tokens',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Prompt cache: ${controller.tokenUsage!.cachedReadTokensLabel} cached tokens '
                    '(${controller.tokenUsage!.cacheHitRatioLabel} hit ratio)',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Measured model cost: ${controller.tokenUsage!.estimatedCostLabel}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _buildProviderPayload() {
    final providerIds = <String>{
      ...widget.controller.aiProviders.map((provider) => provider.id),
      ...widget.controller.aiProviderConfigs.keys,
    };

    return <String, dynamic>{
      for (final providerId in providerIds)
        providerId: <String, dynamic>{
          'enabled':
              _providerEnabled[providerId] ??
              widget.controller.aiProviderConfigs[providerId]?.enabled ??
              true,
          'baseUrl': _providerBaseUrlControllers[providerId]?.text.trim() ?? '',
        },
    };
  }

  void _syncTextController(
    Map<String, TextEditingController> controllers,
    String id,
    String value,
  ) {
    final controller = controllers.putIfAbsent(
      id,
      () => TextEditingController(text: value),
    );
    if (controller.text != value) {
      controller.text = value;
    }
  }

  void _pruneControllers(
    Map<String, TextEditingController> controllers,
    Set<String> activeIds,
  ) {
    final staleIds = controllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      controllers.remove(id)?.dispose();
    }
  }

  Future<_LeaveAction?> _showLeaveDialog(BuildContext context) {
    return showDialog<_LeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved settings. What would you like to do?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Shared helper: small "Test" button + inline result row.
  Widget _buildInlineTestRow({
    required String label,
    required bool running,
    required Map<String, dynamic>? result,
    required VoidCallback onTest,
    String? note,
  }) {
    final passed = result?['passed'] == true;
    final detail = result?['detail']?.toString() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (result != null)
                Row(
                  children: <Widget>[
                    Icon(
                      passed
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 15,
                      color: passed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        passed
                            ? (detail.isNotEmpty ? detail : '$label: OK')
                            : detail,
                        style: TextStyle(
                          fontSize: 13,
                          color: passed ? null : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                )
              else if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: OutlinedButton(
            onPressed: running ? null : onTest,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: running
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test'),
          ),
        ),
      ],
    );
  }
}

class _RoutingSelectCard extends StatelessWidget {
  const _RoutingSelectCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<_ModelPickerOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: _accentHover),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          _ModelPickerButton(
            value: value,
            options: options,
            onChanged: onChanged,
            dialogTitle: 'Select $label',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Pool Summary — compact summary card shown in settings
// ─────────────────────────────────────────────────────────────────────────────

class _SmartPoolSummary extends StatelessWidget {
  const _SmartPoolSummary({
    required this.allModels,
    required this.selectedIds,
    required this.onManage,
  });

  final List<ModelMeta> allModels;
  final Set<String> selectedIds;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final selected = allModels
        .where((m) => selectedIds.contains(m.id) && m.available)
        .toList();
    final providers = <String>{for (final m in selected) m.provider};
    final totalAvailable = allModels.where((m) => m.available).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _accentMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.hub_outlined, size: 18, color: _accentHover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${selected.length} of $totalAvailable models',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    if (providers.isEmpty)
                      Text(
                        'No models selected',
                        style: TextStyle(fontSize: 12, color: _textMuted),
                      )
                    else
                      ...providers
                          .take(12)
                          .map(
                            (p) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: _providerPickerColor(p),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.tune_rounded, size: 14),
            label: const Text('Manage'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Pool Dialog — searchable, grouped multi-select manager
// ─────────────────────────────────────────────────────────────────────────────

class _SmartPoolDialog extends StatefulWidget {
  const _SmartPoolDialog({required this.models, required this.selectedIds});

  final List<ModelMeta> models;
  final Set<String> selectedIds;

  @override
  State<_SmartPoolDialog> createState() => _SmartPoolDialogState();
}

class _SmartPoolDialogState extends State<_SmartPoolDialog> {
  late Set<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyAvailable = true;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ModelMeta> get _filtered {
    var list = _onlyAvailable
        ? widget.models.where((m) => m.available).toList()
        : List<ModelMeta>.from(widget.models);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (m) =>
                m.label.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q) ||
                m.provider.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void _selectAllVisible(List<ModelMeta> filtered) {
    setState(() {
      for (final m in filtered) {
        if (m.available) _selected.add(m.id);
      }
    });
  }

  void _clearAllVisible(List<ModelMeta> filtered) {
    setState(() {
      final toRemove = filtered.map((m) => m.id).toSet();
      final remaining = _selected.difference(toRemove);
      _selected = remaining.isNotEmpty ? remaining : <String>{_selected.first};
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Build grouped structure
    final Map<String, List<ModelMeta>> grouped = <String, List<ModelMeta>>{};
    for (final m in filtered) {
      grouped.putIfAbsent(m.provider, () => <ModelMeta>[]).add(m);
    }
    final providerOrder = grouped.keys.toList();

    final selectedAvailableCount = widget.models
        .where((m) => _selected.contains(m.id) && m.available)
        .length;

    // Build flat row list (headers + model rows)
    final List<Widget> rows = <Widget>[];
    for (final provider in providerOrder) {
      final models = grouped[provider]!;
      final providerColor = _providerPickerColor(provider);
      final available = models.where((m) => m.available).toList();
      final allGroupSelected =
          available.isNotEmpty &&
          available.every((m) => _selected.contains(m.id));

      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: providerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _providerPickerLabel(provider).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: available.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allGroupSelected) {
                            final toRemove = available.map((m) => m.id).toSet();
                            final remaining = _selected.difference(toRemove);
                            _selected = remaining.isNotEmpty
                                ? remaining
                                : <String>{_selected.first};
                          } else {
                            for (final m in available) {
                              _selected.add(m.id);
                            }
                          }
                        });
                      },
                child: Text(
                  allGroupSelected ? 'None' : 'All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: available.isEmpty ? _textMuted : _accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      for (final model in models) {
        rows.add(
          _SmartPoolRow(
            model: model,
            selected: _selected.contains(model.id),
            onToggle: (val) => setState(() {
              if (val) {
                _selected.add(model.id);
              } else if (_selected.length > 1) {
                _selected.remove(model.id);
              }
            }),
          ),
        );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          minWidth: 320,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: _bgCard,
            borderRadius: BorderRadius.circular(20),
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 10, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Smart Selector Pool',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selected),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: _textSecondary,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search + available toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search models or providers…',
                                hintStyle: TextStyle(
                                  color: _textMuted,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: _textMuted,
                                ),
                                suffixIcon: _query.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () => setState(() {
                                          _searchCtrl.clear();
                                          _query = '';
                                        }),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Icon(
                                            Icons.cancel_rounded,
                                            size: 16,
                                            color: _textMuted,
                                          ),
                                        ),
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: _bgSecondary,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(
                              () => _onlyAvailable = !_onlyAvailable,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _onlyAvailable
                                    ? _accentMuted
                                    : _bgSecondary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _onlyAvailable
                                      ? _accent.withValues(alpha: 0.5)
                                      : _border,
                                ),
                              ),
                              child: Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _onlyAvailable
                                      ? _accentHover
                                      : _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick-action toolbar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Row(
                        children: <Widget>[
                          _PoolActionChip(
                            label: 'Select all',
                            onTap: () => _selectAllVisible(filtered),
                          ),
                          const SizedBox(width: 6),
                          _PoolActionChip(
                            label: 'Clear all',
                            onTap: () => _clearAllVisible(filtered),
                          ),
                          const Spacer(),
                          Text(
                            '$selectedAvailableCount selected',
                            style: TextStyle(fontSize: 12, color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: _border),
                    // Model list
                    Flexible(
                      child: rows.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 36,
                                    color: _textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results for "$_query"',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              shrinkWrap: true,
                              children: rows,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Pool Row — individual model row inside the dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SmartPoolRow extends StatelessWidget {
  const _SmartPoolRow({
    required this.model,
    required this.selected,
    required this.onToggle,
  });

  final ModelMeta model;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final color = _providerPickerColor(model.provider);
    return Opacity(
      opacity: model.available ? 1.0 : 0.4,
      child: Material(
        color: selected
            ? _accentMuted.withValues(alpha: 0.12)
            : Colors.transparent,
        child: InkWell(
          onTap: model.available ? () => onToggle(!selected) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: <Widget>[
                // Thin provider accent bar on the left
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.85 : 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: selected,
                    onChanged: model.available
                        ? (v) => onToggle(v ?? false)
                        : null,
                    activeColor: _accent,
                    side: BorderSide(color: _textMuted, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        model.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? _accentHover : _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (model.purpose.isNotEmpty)
                        Text(
                          model.purpose,
                          style: TextStyle(fontSize: 11, color: _textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (model.priceTier != null)
                  _PriceTierChip(tier: model.priceTier!),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Toolbar chip button used inside _SmartPoolDialog
class _PoolActionChip extends StatelessWidget {
  const _PoolActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
      ),
    );
  }
}
