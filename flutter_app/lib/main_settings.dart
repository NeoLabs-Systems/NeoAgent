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

final _timeZoneSettingsSection = _SettingsSection(
  appStrings.timeZone,
  appStrings.timeZone2,
  Icons.schedule_outlined,
  <String>[appStrings.timeZone, 'timezone', 'clock', 'region', 'schedule', 'dst'],
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

final _behaviorSettingsSection = _SettingsSection(
  'behavior',
  'Behavior',
  Icons.psychology_outlined,
  <String>[
    'behavior',
    'persona',
    appStrings.socialIntelligence,
    appStrings.turnTaking,
    'groups',
    'memory',
    'norms',
    'delivery',
  ],
);

final _modelsSettingsSection =
    _SettingsSection('models', appStrings.modelsRouting, Icons.hub_outlined, <String>[
      'models',
      'providers',
      'routing',
      'fallback',
      'chat',
      'sub-agent',
      'subagent',
      appStrings.smartSelector,
      'systemone',
      'system one',
      'decisions',
    ]);

final _advancedSettingsSection =
    _SettingsSection('advanced', 'Advanced', Icons.vpn_key_outlined, <String>[
      'advanced',
      'byok',
      appStrings.bringYourOwnKey,
      appStrings.apiKey2,
      appStrings.customEndpoint,
      appStrings.openaiCompatible,
      appStrings.ownModel,
    ]);

final _socialReachSettingsSection = _SettingsSection(
  appStrings.socialReach,
  appStrings.socialReach2,
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

final _desktopSettingsSection = _SettingsSection(
  'desktop',
  'Desktop',
  Icons.desktop_windows_outlined,
  <String>['desktop', appStrings.localApp, 'tray', 'hotkey'],
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

final List<_SettingsSection> _settingsSearchSections = <_SettingsSection>[
  _overviewSettingsSection,
  _timeZoneSettingsSection,
  _modelsSettingsSection,
  _workspaceSettingsSection,
  _behaviorSettingsSection,
  _socialReachSettingsSection,
  _voiceSettingsSection,
  _desktopSettingsSection,
  _securitySettingsSection,
  _diagnosticsSettingsSection,
  _advancedSettingsSection,
];

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _searchController;
  _SettingsSection _selectedSettingsSection = _overviewSettingsSection;
  late bool _smarterSelector;
  late String _systemOneModel;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _defaultSpeechModel;
  late String _voiceSttProvider;
  late String _voiceSttModel;
  late String _voiceLiveProvider;
  late String _voiceLiveModel;
  late String _voiceLiveVoice;
  late String _voiceInputMode;
  late final TextEditingController _behaviorNotesController;
  late bool _behaviorEnabled;
  late String _behaviorParticipationMode;
  late double _behaviorMinimumNeedScore;
  late double _behaviorBatchWindowMs;
  late String _behaviorDecisionModelId;
  late String _behaviorDeliveryStyle;
  late bool _behaviorSocialMemoryEnabled;
  late bool _behaviorNormsEnabled;
  late bool _behaviorObservabilityEnabled;

  bool _hasUnsavedChanges = false;
  Object? _hydratedSettingsSource;
  Object? _hydratedBehaviorSource;
  Object? _hydratedMemorySource;
  Object? _hydratedProvidersSource;
  Object? _hydratedModelsSource;

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
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _searchController.dispose();
    _behaviorNotesController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _hydrate();
    } else if (!_hasUnsavedChanges && _hydrationSourcesChanged()) {
      _hydrate();
    }
  }

  void _handleControllerChanged() {
    if (!mounted || _hasUnsavedChanges || !_hydrationSourcesChanged()) return;
    setState(_hydrate);
  }

  bool _hydrationSourcesChanged() {
    final controller = widget.controller;
    return !identical(_hydratedSettingsSource, controller.settings) ||
        !identical(_hydratedBehaviorSource, controller.behaviorConfig) ||
        !identical(_hydratedMemorySource, controller.memoryOverview) ||
        !identical(_hydratedProvidersSource, controller.aiProviders) ||
        !identical(_hydratedModelsSource, controller.supportedModels);
  }

  void _rememberHydrationSources() {
    final controller = widget.controller;
    _hydratedSettingsSource = controller.settings;
    _hydratedBehaviorSource = controller.behaviorConfig;
    _hydratedMemorySource = controller.memoryOverview;
    _hydratedProvidersSource = controller.aiProviders;
    _hydratedModelsSource = controller.supportedModels;
  }

  void _hydrate() {
    final controller = widget.controller;
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toSet();
    _smarterSelector = controller.smarterSelector;
    _systemOneModel = controller.systemOneModel;
    // Saved selections are user-owned. Catalog availability may affect whether
    // a run can use a model, but it must never rewrite the saved routing pool.
    _enabledModels = controller.enabledModelIds.toSet();
    if (_enabledModels.isEmpty && availableModels.isNotEmpty) {
      _enabledModels = availableModels;
    }
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _defaultSpeechModel = controller.defaultSpeechModel;
    _voiceSttProvider = controller.voiceSttProvider;
    _voiceSttModel = controller.voiceSttModel;
    _voiceLiveProvider = controller.voiceLiveProvider;
    _voiceLiveModel = controller.voiceLiveModel;
    _voiceLiveVoice = controller.voiceLiveVoice;
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
        ((behavior['minimumNeedScore'] as num?)?.toDouble() ?? 0.58)
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
    _behaviorSocialMemoryEnabled = moduleEnabled('social_memory');
    _behaviorNormsEnabled = moduleEnabled('norms');
    _behaviorObservabilityEnabled = moduleEnabled('social_observability');
    final behaviorNotes = controller.memoryOverview.assistantBehaviorNotes;
    if (_behaviorNotesController.text != behaviorNotes) {
      _behaviorNotesController.text = behaviorNotes;
    }
    _rememberHydrationSources();
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
              subtitle: appStrings.workspaceModelsAndDiagnosticsControls,
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
                          appStrings.generalSettings,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appStrings.chooseACategoryOrSearchAcross,
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
            _InlineError(
              message: controller.errorMessage!,
              onDismiss: controller.clearInlineError,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: appStrings.searchSettings,
              hintText: appStrings.modelsBrowserVoiceDiagnostics,
              prefixIcon: Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
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
            _timeZoneSettingsSection,
          )) ...<Widget>[
            _TimeZoneSettingsCard(controller: controller),
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
            _advancedSettingsSection,
          )) ...<Widget>[
            _ByokSettingsCard(controller: controller),
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
            _EmptyCard(
              title: appStrings.noMatchingSettings,
              subtitle: appStrings.tryABroaderSearchLikeModels,
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
            decoration: InputDecoration(
              labelText: appStrings.category,
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
      systemOneModel: _systemOneModel,
      enabledModels: _enabledModels.toList(),
      defaultChatModel: _defaultChatModel,
      defaultSubagentModel: _defaultSubagentModel,
      defaultSpeechModel: _defaultSpeechModel,
      voiceSttProvider: _voiceSttProvider,
      voiceSttModel: _voiceSttModel,
      voiceLiveProvider: _voiceLiveProvider,
      voiceLiveModel: _voiceLiveModel,
      voiceLiveVoice: _voiceLiveVoice,
      voiceInputMode: _voiceInputMode,
    );
    if (controller.errorMessage != null) return;
    final existingModules = controller.behaviorConfig['modules'] is Map
        ? Map<String, dynamic>.from(controller.behaviorConfig['modules'] as Map)
        : <String, dynamic>{};
    existingModules.addAll(<String, dynamic>{
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
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _rememberHydrationSources();
      });
    }
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
      label: Text(appStrings.save),
    );
    if (!_hasUnsavedChanges) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          appStrings.unsavedChanges,
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
            _SectionTitle(appStrings.sectionOverview),
            const SizedBox(height: 10),
            Text(
              appStrings.configureWorkspaceBehaviorAndModelDefaults,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            if (availableModelCount == 0 &&
                !controller.isRefreshing) ...<Widget>[
              const SizedBox(height: 14),
              _InlineError(
                message:
                    appStrings.noAiProviderIsConfiguredSo +
                    appStrings.cannotRunYet,
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
                      appStrings.platformArg1Arg2(platformLabel[0].toUpperCase(), platformLabel.substring(1)),
                ),
                _MetaPill(
                  icon: Icons.memory_outlined,
                  label: appStrings.arg1ModelsReady(availableModelCount),
                ),
                _MetaPill(
                  icon: Icons.hub_outlined,
                  label: appStrings.arg1Providers(controller.aiProviders.length),
                ),
                _MetaPill(
                  icon: Icons.auto_awesome_outlined,
                  label: _smarterSelector
                      ? appStrings.smartSelectorOn
                      : appStrings.manualRouting,
                ),
                if (_supportsDesktopShell)
                  _MetaPill(
                    icon: Icons.desktop_windows_outlined,
                    label: appStrings.desktopAppControlsAvailable,
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
                icon: Icon(Icons.replay_rounded, size: 18),
                label: Text(appStrings.redoOnboarding),
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
            _SectionTitle(appStrings.behaviorModules),
            const SizedBox(height: 10),
            Text(
              appStrings.oneRuntimeControlsPersonaGroupTurn,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(appStrings.enableBehaviorModules),
              subtitle: Text(
                appStrings.directMessagesRemainResponsiveAllowlistedGroups,
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
              decoration: InputDecoration(
                labelText: appStrings.defaultGroupParticipation,
                helperText:
                    appStrings.automaticReadsTheRoomAndNormally,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'automatic',
                  child: Text(appStrings.automaticReserved),
                ),
                DropdownMenuItem(
                  value: 'mention_only',
                  child: Text(appStrings.mentionOrReplyOnly),
                ),
                DropdownMenuItem(value: 'always', child: Text(appStrings.alwaysEngage)),
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
              appStrings.minimumContributionValueArg1(_behaviorMinimumNeedScore.toStringAsFixed(2)),
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
              appStrings.higherValuesMakeNeoagentMoreSelective,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              appStrings.roomBatchWindowArg1Ms(_behaviorBatchWindowMs.round()),
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
              label: appStrings.arg1Ms(_behaviorBatchWindowMs.round()),
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
              decoration: InputDecoration(
                labelText: appStrings.turnTakingModel,
                helperText:
                    controller.systemOneAvailable && _systemOneModel != 'off'
                    ? appStrings.systemOneDecidesWhenToSpeakWhileIt
                    : appStrings.automaticSelectsAFastModelThrough,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: '',
                  child: Text(appStrings.automaticFast),
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
              decoration: InputDecoration(
                labelText: appStrings.messagingDelivery,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'natural_bubbles',
                  child: Text(appStrings.naturalBubbles),
                ),
                DropdownMenuItem(
                  value: 'single',
                  child: Text(appStrings.singleMessage),
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
              title: Text(appStrings.channelScopedSocialMemory),
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
              title: Text(appStrings.learnRoomNorms),
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
              title: Text(appStrings.socialObservability),
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
              decoration: InputDecoration(
                labelText: appStrings.personaBehaviorNotes,
                helperText:
                    appStrings.durableInstructionsForVoiceAndInteraction,
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
            _SectionTitle(appStrings.computerWorkspace),
            const SizedBox(height: 10),
            Text(
              appStrings.browserLinuxDesktopFilesTerminalAnd,
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
                  icon: Icon(Icons.computer_outlined),
                  label: Text(appStrings.openComputer),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isRunningDeviceAction
                      ? null
                      : controller.stopComputerRuntime,
                  icon: Icon(Icons.stop_circle_outlined),
                  label: Text(appStrings.stop),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              appStrings.theRuntimeIsALightweightDebian,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const Divider(height: 32),
            _buildInlineTestRow(
              label: appStrings.computerShell,
              running: _cliTestRunning,
              result: _cliTestResult,
              note:
                  appStrings.commandsRunInTheSamePersistent,
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
              title: appStrings.smartModelSelection,
              subtitle:
                  appStrings.automaticallyChooseTheBestEnabledModel,
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
                Expanded(child: _SectionTitle(appStrings.socialReach3)),
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
                      : Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              appStrings.socialSourcesAgentsCanReadDirectly,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.check_circle_outline,
                  label: appStrings.arg1Ready(ready),
                  color: _success,
                ),
                _MetaPill(
                  icon: Icons.play_circle_outline,
                  label: appStrings.videoLinks,
                  color: _info,
                ),
                if (cookieSetup > 0)
                  _MetaPill(
                    icon: Icons.computer_outlined,
                    label: appStrings.cookieSetup,
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
                      appStrings.socialReachUpdated,
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
                appStrings.statusIsNotLoadedYet,
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
                  ? appStrings.arg1CookiesImported(cookie['count'] ?? 0)
                  : appStrings.cookiesNotConfigured,
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
                      : Icon(Icons.computer_outlined, size: 18),
                  label: Text(appStrings.importFromComputer),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _runSocialReachAction(
                          controller,
                          id,
                          () => controller.clearSocialReachCookies(id),
                        ),
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text(appStrings.clear),
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
            _SectionTitle(appStrings.models),
            const SizedBox(height: 10),
            Text(
              appStrings.chooseDefaultsForChatAgentsFallback,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              appStrings.sharedProviderKeysAreConfiguredOn,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            Text(
              appStrings.defaultRouting,
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
                          label: appStrings.subAgent,
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
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            _SystemOneSettingCard(
              selection: _systemOneModel,
              models: controller.systemOneModels
                  .where((model) => model.available)
                  .toList(),
              onChanged: (value) => setState(() {
                _systemOneModel = value;
                _hasUnsavedChanges = true;
              }),
            ),
            const Divider(height: 32),
            Text(
              appStrings.smartSelectorPool,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              appStrings.theModelsTheSmartSelectorRoutes,
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
    final capabilities = controller.voiceCapabilities;
    final liveProviders = _jsonList(
      capabilities['providers'],
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    final defaultProviderId =
        capabilities['defaultProvider']?.toString() ?? 'openai';
    Map<String, dynamic> liveProvider(String id) => liveProviders.firstWhere(
      (item) => item['id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    final serverDefault = liveProvider(defaultProviderId);
    final effective = liveProvider(
      _voiceLiveProvider.isEmpty ? defaultProviderId : _voiceLiveProvider,
    );
    List<_ModelPickerOption> withDefault(
      String defaultLabel,
      List<String> values,
      String current,
    ) {
      return <_ModelPickerOption>[
        _ModelPickerOption(value: '', label: defaultLabel),
        for (final value in <String>{
          ...values,
          if (current.isNotEmpty) current,
        })
          _ModelPickerOption(value: value, label: value),
      ];
    }

    final providerOptions = <_ModelPickerOption>[
      _ModelPickerOption(
        value: '',
        label:
            appStrings.serverDefaultArg1(serverDefault['label'] ?? defaultProviderId),
      ),
      for (final provider in liveProviders)
        _ModelPickerOption(
          value: provider['id']?.toString() ?? '',
          label: provider['label']?.toString() ?? '',
        ),
    ];
    final modelOptions = withDefault(
      appStrings.defaultArg1(effective['defaultModel'] ?? 'provider default'),
      _jsonStringList(effective['models']),
      _voiceLiveModel,
    );
    final voiceOptions = withDefault(
      appStrings.defaultArg1(effective['defaultVoice'] ?? 'provider default'),
      _jsonStringList(effective['voices']),
      _voiceLiveVoice,
    );
    final inputModeOptions = <_ModelPickerOption>[
      _ModelPickerOption(
        value: 'hands_free',
        label: appStrings.handsFreeTalkFreelyInterruptAnytime,
      ),
      _ModelPickerOption(value: 'ptt', label: appStrings.pushToTalk),
    ];
    final sttOptions = <_ModelPickerOption>[
      _ModelPickerOption(
        value: 'auto',
        label: appStrings.autoFirstProviderWithAnApi,
      ),
      for (final provider in _jsonList(
        _jsonMap(capabilities['transcription'])['providers'],
      ).whereType<Map>())
        _ModelPickerOption(
          value: provider['id']?.toString() ?? '',
          label: provider['id']?.toString() ?? '',
        ),
    ];
    String sttDefaultModel(String id) {
      for (final provider in _jsonList(
        _jsonMap(capabilities['transcription'])['providers'],
      ).whereType<Map>()) {
        if (provider['id']?.toString() == id) {
          return provider['defaultModel']?.toString() ?? '';
        }
      }
      return '';
    }

    Widget pickerGrid(List<Widget> cards) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 940;
          final cardWidth = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(growable: false),
          );
        },
      );
    }

    void update(VoidCallback change) {
      setState(() {
        change();
        _hasUnsavedChanges = true;
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SectionTitle(appStrings.voice),
            const SizedBox(height: 10),
            Text(
              appStrings.voiceCallsRunOnALive,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              appStrings.liveVoice,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            pickerGrid(<Widget>[
              _RoutingSelectCard(
                label: appStrings.liveModelProvider,
                icon: Icons.graphic_eq_outlined,
                value: _voiceLiveProvider,
                options: providerOptions,
                onChanged: (value) {
                  if (value == null) return;
                  update(() {
                    _voiceLiveProvider = value;
                    _voiceLiveModel = '';
                    _voiceLiveVoice = '';
                  });
                },
              ),
              _RoutingSelectCard(
                label: appStrings.liveModel,
                icon: Icons.memory_outlined,
                value: _voiceLiveModel,
                options: modelOptions,
                onChanged: (value) {
                  if (value != null) update(() => _voiceLiveModel = value);
                },
              ),
              _RoutingSelectCard(
                label: appStrings.voice,
                icon: Icons.record_voice_over_outlined,
                value: _voiceLiveVoice,
                options: voiceOptions,
                onChanged: (value) {
                  if (value != null) update(() => _voiceLiveVoice = value);
                },
              ),
              _RoutingSelectCard(
                label: appStrings.inputMode,
                icon: Icons.mic_outlined,
                value: _voiceInputMode,
                options: inputModeOptions,
                onChanged: (value) {
                  if (value != null) update(() => _voiceInputMode = value);
                },
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              appStrings.gptLiveUsesYourOpenaiApi,
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const Divider(height: 32),
            Text(
              appStrings.voiceNotesAndDictation,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            pickerGrid(<Widget>[
              _RoutingSelectCard(
                label: appStrings.speechToText,
                icon: Icons.hearing_outlined,
                value: _voiceSttProvider,
                options: sttOptions,
                onChanged: (value) {
                  if (value == null) return;
                  update(() {
                    _voiceSttProvider = value;
                    _voiceSttModel = value == 'auto'
                        ? ''
                        : sttDefaultModel(value);
                  });
                },
              ),
              _RoutingSelectCard(
                label: appStrings.voiceReplyModel,
                icon: Icons.chat_bubble_outline,
                value: _ensureModelValue(
                  _defaultSpeechModel,
                  routingModels,
                  allowAuto: true,
                  preserveUnknown: true,
                ),
                options: modelChoices,
                onChanged: (value) {
                  if (value != null) update(() => _defaultSpeechModel = value);
                },
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              appStrings.speechToTextTranscribesVoiceNotes,
              style: TextStyle(color: _textSecondary, height: 1.4),
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
            _SectionTitle(appStrings.desktopApp),
            const SizedBox(height: 10),
            Text(
              appStrings.localPreferencesForTheNeoagentApplication,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: controller.desktopAskOnClose,
              contentPadding: EdgeInsets.zero,
              title: Text(appStrings.askBeforeClosingToBackground),
              subtitle: Text(
                appStrings.promptBeforeNeoagentStaysResidentIn,
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
              title: Text(appStrings.reserveAssistantHotkey),
              subtitle: Text(
                appStrings.registerArg1ForTheAssistantSummon(_desktopAssistantHotkeyLabel),
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
            _SectionTitle(appStrings.security),
            const SizedBox(height: 10),
            Text(
              appStrings.perToolPermissionPoliciesApprovalGates,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.checklist_outlined, color: _accentAlt),
              title: Text(appStrings.toolPermissions),
              subtitle: Text(
                appStrings.setBlockAskAllowPerTool,
                style: TextStyle(color: _textSecondary),
              ),
              trailing: Icon(Icons.chevron_right),
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
                _SectionTitle(appStrings.sectionDiagnostics),
                const SizedBox(width: 8),
                Icon(Icons.info_outline, size: 16, color: _textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              appStrings.usageAndHealthSignalsThatHelp,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (controller.tokenUsage == null)
              Text(
                appStrings.tokenUsageUnavailableOnThisServer,
                style: TextStyle(color: _textSecondary),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    appStrings.totalArg1TokensAcrossArg2Runs(controller.tokenUsage!.totalTokensLabel, controller.tokenUsage!.totalRunsLabel),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appStrings.last7DaysArg1TokensIn(controller.tokenUsage!.last7DaysTokensLabel, controller.tokenUsage!.last7DaysRunsLabel),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appStrings.avgRunArg1Tokens(controller.tokenUsage!.avgTokensPerRunLabel),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appStrings.promptCacheArg1CachedTokens(controller.tokenUsage!.cachedReadTokensLabel) +
                    appStrings.arg1HitRatio(controller.tokenUsage!.cacheHitRatioLabel),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    appStrings.measuredModelCostArg1(controller.tokenUsage!.estimatedCostLabel),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<_LeaveAction?> _showLeaveDialog(BuildContext context) {
    return showDialog<_LeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appStrings.unsavedChanges),
        content: Text(
          appStrings.youHaveUnsavedSettingsWhatWould,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.cancel),
            child: Text(appStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.discard),
            child: Text(appStrings.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.save),
            child: Text(appStrings.save),
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
                      color: passed ? _success : _danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        passed
                            ? (detail.isNotEmpty ? detail : appStrings.arg1Ok(label))
                            : detail,
                        style: TextStyle(
                          fontSize: 13,
                          color: passed ? null : _danger,
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
                : Text('Test'),
          ),
        ),
      ],
    );
  }
}

class _TimeZoneSettingsCard extends StatefulWidget {
  const _TimeZoneSettingsCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_TimeZoneSettingsCard> createState() => _TimeZoneSettingsCardState();
}

class _TimeZoneSettingsCardState extends State<_TimeZoneSettingsCard> {
  List<String> _zones = const <String>[];
  String? _deviceZone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final deviceZone = await widget.controller.deviceTimeZone();
    List<String> zones = const <String>[];
    try {
      zones =
          (await FlutterTimezone.getAvailableTimezones())
              .map((zone) => zone.identifier)
              .toSet()
              .toList()
            ..sort();
    } catch (error) {
      debugPrint(appStrings.timezoneCouldNotListTimeZones(error));
    }
    if (!mounted) return;
    setState(() {
      _deviceZone = deviceZone;
      _zones = zones;
    });
  }

  Future<void> _save(Map<String, dynamic> payload) async {
    setState(() => _saving = true);
    try {
      await widget.controller.saveSettingsPayload(payload);
    } catch (_) {
      // saveSettingsPayload shows the error inline.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setFollowsDevice(bool follow) {
    final deviceZone = _deviceZone;
    _save(<String, dynamic>{
      'timezone_auto': follow,
      if (follow && deviceZone != null) 'timezone': deviceZone,
    });
  }

  void _chooseZone(String zone) {
    if (zone == widget.controller.timeZone) return;
    _save(<String, dynamic>{'timezone_auto': false, 'timezone': zone});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final followsDevice = controller.timeZoneFollowsDevice;
    final current = controller.timeZone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SectionTitle(appStrings.timeZone2),
            const SizedBox(height: 10),
            Text(
              appStrings.theAgentReadsTimesYouMention,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.public,
                  label: current.isEmpty ? appStrings.notSet : current,
                ),
                if (_deviceZone != null)
                  _MetaPill(
                    icon: Icons.devices_outlined,
                    label: appStrings.thisDeviceArg1(_deviceZone),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _SettingToggle(
              title: appStrings.matchThisDevice,
              subtitle:
                  appStrings.updateTheTimeZoneAutomaticallyFrom,
              value: followsDevice,
              onChanged: _setFollowsDevice,
            ),
            const SizedBox(height: 8),
            if (_zones.isNotEmpty)
              DropdownMenu<String>(
                key: ValueKey<String>('timezone-$current-$followsDevice'),
                enabled: !followsDevice && !_saving,
                initialSelection: _zones.contains(current) ? current : null,
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                requestFocusOnTap: true,
                menuHeight: 320,
                label: Text(appStrings.timeZone2),
                leadingIcon: Icon(Icons.search),
                dropdownMenuEntries: _zones
                    .map(
                      (zone) =>
                          DropdownMenuEntry<String>(value: zone, label: zone),
                    )
                    .toList(),
                onSelected: (zone) {
                  if (zone != null) _chooseZone(zone);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The per-agent SystemOne model choice, shown under the model selectors. It
/// uses the same picker as the chat models but lists only the available
/// SystemOne models, plus Auto and Off.
class _SystemOneSettingCard extends StatelessWidget {
  const _SystemOneSettingCard({
    required this.selection,
    required this.models,
    required this.onChanged,
  });

  final String selection;
  final List<ModelMeta> models;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <_ModelPickerOption>[
      _ModelPickerOption(
        value: 'auto',
        label: appStrings.systemOneAuto,
        subtitle: appStrings.systemOneAutoPicksTheBestAvailable,
        icon: Icons.auto_awesome_outlined,
        isAuto: true,
      ),
      _ModelPickerOption(
        value: 'off',
        label: appStrings.off,
        subtitle: appStrings.systemOneOffTheChatModelDecides,
        icon: Icons.block_outlined,
      ),
      ..._modelPickerOptions(models),
    ];
    return _PanelSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                appStrings.systemOneModels,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _StatusPill(label: appStrings.highlyRecommended, color: _accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            appStrings.systemOneModelsMakeTheBehindTheScenes,
            style: TextStyle(color: _textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                icon: Icons.speed_rounded,
                label: appStrings.fasterReplies,
                color: _accent,
              ),
              _MetaPill(
                icon: Icons.savings_outlined,
                label: appStrings.fewerModelCalls,
                color: _accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RoutingSelectCard(
            label: 'SystemOne',
            icon: Icons.bolt_rounded,
            value: _ensureModelValue(
              selection,
              models,
              allowAuto: true,
              preserveUnknown: true,
            ),
            options: options,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
          if (models.isEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              appStrings.noSystemOneModelIsAvailableYet,
              style: TextStyle(color: _textMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ],
      ),
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
            dialogTitle: appStrings.selectArg1(label),
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
                  appStrings.arg1OfArg2Models(selected.length, totalAvailable),
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
                        appStrings.noModelsSelected,
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
            icon: Icon(Icons.tune_rounded, size: 14),
            label: Text(appStrings.manage),
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
                              appStrings.smartSelectorPool,
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
                                hintText: appStrings.searchModelsOrProviders2,
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
                                appStrings.available,
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
                            label: appStrings.selectAll,
                            onTap: () => _selectAllVisible(filtered),
                          ),
                          const SizedBox(width: 6),
                          _PoolActionChip(
                            label: appStrings.clearAll,
                            onTap: () => _clearAllVisible(filtered),
                          ),
                          const Spacer(),
                          Text(
                            appStrings.arg1Selected(selectedAvailableCount),
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
                                    appStrings.noResultsForArg1(_query),
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
                if (model.isByok) ...<Widget>[
                  const _ByokChip(),
                  const SizedBox(width: 6),
                ],
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
