part of 'main.dart';

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

const Map<String, List<String>> _voiceLiveModelsByProvider =
    <String, List<String>>{
      'openai': <String>[
        'gpt-4o-realtime-preview',
        'gpt-4o-mini-realtime-preview',
      ],
      'gemini': <String>['gemini-3.1-flash-live-preview'],
    };

const Map<String, List<String>> _voiceLiveVoicesByProvider =
    <String, List<String>>{
      'openai': <String>[
        'alloy',
        'ash',
        'ballad',
        'coral',
        'echo',
        'fable',
        'nova',
        'onyx',
        'sage',
        'shimmer',
        'verse',
        'marin',
        'cedar',
      ],
      'gemini': <String>[
        'Kore',
        'Puck',
        'Charon',
        'Zephyr',
        'Leda',
        'Aoede',
        'Fenrir',
        'Orus',
        'Achernar',
        'Achird',
        'Algenib',
        'Algieba',
        'Alnilam',
        'Autonoe',
        'Callirrhoe',
        'Despina',
        'Enceladus',
        'Erinome',
        'Gacrux',
        'Iocaste',
        'Isonoe',
        'Laomedeia',
        'Larissa',
        'Lysithea',
        'Megaclite',
        'Mimosa',
        'Pulcherrima',
        'Rasalgethi',
        'Sadachbia',
        'Sulafat',
      ],
    };

class _SettingsSection {
  const _SettingsSection(
    this.title,
    this.keywords, {
    this.requiresDesktop = false,
  });

  final String title;
  final List<String> keywords;
  final bool requiresDesktop;
}

const _overviewSettingsSection = _SettingsSection('overview', <String>[
  'overview',
  'summary',
  'onboarding',
  'platform',
  'providers',
]);

const _workspaceSettingsSection = _SettingsSection('workspace', <String>[
  'workspace',
  'browser',
  'extension',
  'cli',
  'claude code',
  'desktop',
  'routing',
]);

const _modelsSettingsSection = _SettingsSection('models', <String>[
  'models',
  'providers',
  'routing',
  'fallback',
  'chat',
  'sub-agent',
  'subagent',
  'smart selector',
]);

const _voiceRecordingSettingsSection = _SettingsSection(
  'voice recording',
  <String>[
    'voice',
    'recording',
    'transcription',
    'summary',
    'speech',
    'tts',
    'stt',
    'live',
  ],
);

const _desktopSettingsSection = _SettingsSection('desktop', <String>[
  'desktop',
  'permissions',
  'capture',
  'companion',
  'screen recording',
  'accessibility',
  'input',
], requiresDesktop: true);

const _diagnosticsSettingsSection = _SettingsSection('diagnostics', <String>[
  'diagnostics',
  'logs',
  'token',
  'usage',
  'debug',
  'health',
]);

const List<_SettingsSection> _settingsSearchSections = <_SettingsSection>[
  _overviewSettingsSection,
  _workspaceSettingsSection,
  _modelsSettingsSection,
  _voiceRecordingSettingsSection,
  _desktopSettingsSection,
  _diagnosticsSettingsSection,
];

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _searchController;
  late String _browserBackend;
  String? _browserExtensionTokenId;
  late String _cliBackend;
  String? _cliDesktopDeviceId;
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _defaultRecordingTranscriptionModel;
  late String _defaultRecordingSummaryModel;
  late String _fallbackModel;
  late String _defaultSpeechModel;
  late String _voiceLiveProvider;
  late String _voiceLiveModel;
  late String _voiceLiveVoice;
  final Map<String, bool> _providerEnabled = <String, bool>{};
  final Map<String, TextEditingController> _providerBaseUrlControllers =
      <String, TextEditingController>{};

  // Inline runtime test state — ephemeral, not stored in controller.
  bool _cliTestRunning = false;
  Map<String, dynamic>? _cliTestResult;
  bool _extensionTestRunning = false;
  Map<String, dynamic>? _extensionTestResult;
  bool _desktopTestRunning = false;
  Map<String, dynamic>? _desktopTestResult;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _hydrate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _providerBaseUrlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings != widget.controller.settings ||
        oldWidget.controller.aiProviders != widget.controller.aiProviders ||
        oldWidget.controller.supportedModels !=
            widget.controller.supportedModels) {
      _hydrate();
    }
  }

  void _hydrate() {
    final controller = widget.controller;
    final knownModels = controller.supportedModels
        .map((model) => model.id)
        .toSet();
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toSet();
    _browserBackend = _normalizeBrowserBackend(controller.browserBackend);
    _browserExtensionTokenId =
        controller.browserExtensionTokenId ??
        controller.selectedBrowserExtensionTokenId;
    _cliBackend = _normalizeCliBackend(controller.cliBackend);
    _cliDesktopDeviceId = controller.cliDesktopDeviceId;
    _smarterSelector = controller.smarterSelector;
    _enabledModels = controller.enabledModelIds
        .where((id) => knownModels.contains(id))
        .toSet();
    if (_enabledModels.isEmpty && availableModels.isNotEmpty) {
      _enabledModels = availableModels;
    }
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _defaultRecordingTranscriptionModel =
        controller.defaultRecordingTranscriptionModel;
    _defaultRecordingSummaryModel = controller.defaultRecordingSummaryModel;
    _fallbackModel = controller.fallbackModel;
    _defaultSpeechModel = controller.defaultSpeechModel;
    _voiceLiveProvider = controller.voiceLiveProvider;
    _voiceLiveModel = controller.voiceLiveModel;
    _voiceLiveVoice = controller.voiceLiveVoice;
    if (!_voiceLiveModelsByProvider.containsKey(_voiceLiveProvider)) {
      _voiceLiveProvider = 'openai';
    }
    if (!(_voiceLiveModelsByProvider[_voiceLiveProvider]?.contains(
          _voiceLiveModel,
        ) ??
        false)) {
      _voiceLiveModel = _voiceLiveModelsByProvider[_voiceLiveProvider]!.first;
    }
    final liveVoiceOptions =
        _voiceLiveVoicesByProvider[_voiceLiveProvider] ?? const <String>[];
    if (liveVoiceOptions.isNotEmpty &&
        !liveVoiceOptions.contains(_voiceLiveVoice)) {
      _voiceLiveVoice = liveVoiceOptions.first;
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

  String _normalizeBrowserBackend(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'extension' ? 'extension' : 'vm';
  }

  String _normalizeCliBackend(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'desktop' ? 'desktop' : 'vm';
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
    final List<_ModelPickerOption> modelChoices =
        _modelPickerOptions(routingModels, allowAuto: true);
    final enabledSmartModels = _enabledModels
        .where((id) => routingModels.any((model) => model.id == id))
        .length;
    final visibleSearchSections = _settingsSearchSections
        .where((section) => !section.requiresDesktop || _supportsDesktopShell)
        .toSet();

    return ListView(
      padding: widget.embedded ? EdgeInsets.zero : _pagePadding(context),
      children: <Widget>[
        if (!widget.embedded)
          _PageTitle(
            title: 'Settings',
            subtitle:
                'Workspace, models, recording, and diagnostics controls.',
            trailing: _settingsSaveButton(controller),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _settingsSaveButton(controller),
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
        const SizedBox(height: 16),
        if (_matchesSettingsSection(
          searchQuery,
          _overviewSettingsSection,
        )) ...<Widget>[
          _buildSettingsOverview(controller, availableModels.length),
          const SizedBox(height: 16),
        ],
        if (_matchesSettingsSection(
          searchQuery,
          _workspaceSettingsSection,
        )) ...<Widget>[
          _buildWorkspaceSection(controller),
          const SizedBox(height: 16),
        ],
        if (_matchesSettingsSection(
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
        if (_matchesSettingsSection(
          searchQuery,
          _voiceRecordingSettingsSection,
        )) ...<Widget>[
          _buildVoiceAndRecordingSection(
            controller: controller,
            modelChoices: modelChoices,
            routingModels: routingModels,
          ),
          const SizedBox(height: 16),
        ],
        if (visibleSearchSections.contains(_desktopSettingsSection) &&
            _matchesSettingsSection(
              searchQuery,
              _desktopSettingsSection,
            )) ...<Widget>[
          _buildDesktopSection(controller),
          const SizedBox(height: 16),
        ],
        if (_matchesSettingsSection(
          searchQuery,
          _diagnosticsSettingsSection,
        )) ...<Widget>[_buildDiagnosticsSection(controller)],
        if (_noSettingsMatches(searchQuery, visibleSearchSections)) ...<Widget>[
          const _EmptyCard(
            title: 'No matching settings',
            subtitle:
                'Try a broader search like models, browser, or voice.',
          ),
        ],
      ],
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

  Widget _settingsSaveButton(NeoAgentController controller) {
    return FilledButton.icon(
      onPressed: controller.isSavingSettings
          ? null
          : () => controller.saveSettings(
              browserBackend: _browserBackend == 'extension'
                  ? 'extension'
                  : 'vm',
              browserExtensionTokenId: _browserBackend == 'extension'
                  ? _browserExtensionTokenId
                  : null,
              cliBackend: _cliBackend == 'desktop' ? 'desktop' : 'vm',
              cliDesktopDeviceId: _cliDesktopDeviceId,
              smarterSelector: _smarterSelector,
              enabledModels: _enabledModels.toList(),
              defaultChatModel: _defaultChatModel,
              defaultSubagentModel: _defaultSubagentModel,
              defaultRecordingTranscriptionProvider: 'deepgram',
              defaultRecordingTranscriptionModel:
                  _defaultRecordingTranscriptionModel,
              defaultRecordingSummaryProvider: _providerForSelectedModel(
                _defaultRecordingSummaryModel,
                controller.supportedModels,
              ),
              defaultRecordingSummaryModel: _defaultRecordingSummaryModel,
              fallbackModel: _fallbackModel,
              defaultSpeechModel: _defaultSpeechModel,
              voiceSttProvider: controller.voiceSttProvider,
              voiceSttModel: controller.voiceSttModel,
              voiceTtsProvider: controller.voiceTtsProvider,
              voiceTtsModel: controller.voiceTtsModel,
              voiceTtsVoice: controller.voiceTtsVoice,
              voiceRuntimeMode: 'live',
              voiceLiveProvider: _voiceLiveProvider,
              voiceLiveModel: _voiceLiveModel,
              voiceLiveVoice: _voiceLiveVoice,
              aiProviderConfigs: _buildProviderPayload(),
            ),
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
  }

  Widget _inlineProgressIndicator() {
    return SizedBox(
      width: 28,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.28),
          color: Colors.white,
        ),
      ),
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
              'Configure workspace behavior, models, and recording defaults.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
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
                  _MetaPill(
                    icon: Icons.desktop_windows_outlined,
                    label: controller.desktopCompanionEnabled
                        ? 'Desktop companion enabled'
                        : 'Desktop-only controls available',
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

  Widget _buildWorkspaceSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Workspace'),
            const SizedBox(height: 10),
            Text(
              'Controls for how the app runs on this device and in the browser.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Browser Runtime',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _browserBackend,
              decoration: const InputDecoration(
                labelText: 'Browser backend',
                helperText:
                    'Cloud uses the isolated browser runtime. Extension uses a paired Chrome browser on the remote machine.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'vm', child: Text('Cloud')),
                DropdownMenuItem<String>(
                  value: 'extension',
                  child: Text('Chrome extension'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _browserBackend = value;
                    _browserExtensionTokenId ??=
                        controller.selectedBrowserExtensionTokenId;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            if (_browserBackend == 'extension') ...<Widget>[
              if (controller.browserExtensionTokens.isNotEmpty) ...<Widget>[
                DropdownButtonFormField<String>(
                  initialValue: controller.browserExtensionTokens.any(
                    (token) => token['tokenId']?.toString() == _browserExtensionTokenId,
                  )
                      ? _browserExtensionTokenId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Default extension',
                    helperText: 'Choose which paired Chrome extension controls browser actions.',
                  ),
                  items: controller.browserExtensionTokens.map((token) {
                    final tokenId = token['tokenId']?.toString() ?? '';
                    final label = token['name']?.toString().trim().isNotEmpty == true
                        ? token['name'].toString()
                        : tokenId;
                    final online = token['online'] == true || token['connected'] == true;
                    return DropdownMenuItem<String>(
                      value: tokenId,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            online ? Icons.circle : Icons.circle_outlined,
                            size: 10,
                            color: online ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _browserExtensionTokenId = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
              _buildInlineTestRow(
                label: 'Chrome extension',
                running: _extensionTestRunning,
                result: _extensionTestResult,
                note: controller.browserExtensionConnected
                    ? 'Connected — tap Test to verify the live link.'
                    : 'Not connected — download the extension, load it in Chrome, then pair after login.',
                onTest: () async {
                  setState(() { _extensionTestRunning = true; _extensionTestResult = null; });
                  try {
                    final r = await controller.testBrowserExtension();
                    if (mounted) {
                      setState(() => _extensionTestResult = r);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _extensionTestResult = <String, dynamic>{'passed': false, 'detail': e.toString()});
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _extensionTestRunning = false);
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: controller.downloadBrowserExtension,
                    icon: Icon(Icons.download_outlined),
                    label: Text('Download extension'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.refreshBrowserExtensionStatus,
                    icon: Icon(Icons.sync),
                    label: Text('Refresh'),
                  ),
                ],
              ),
            ] else ...<Widget>[
              Text('Cloud browser runtime is active.', style: TextStyle(color: _textSecondary, height: 1.4)),
            ],
            const Divider(height: 32),
            Text(
              'CLI Runtime',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _cliBackend,
              decoration: const InputDecoration(
                labelText: 'CLI backend',
                helperText:
                    'Cloud runs the CLI in the isolated VM. Desktop app runs it through the connected desktop companion.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'vm', child: Text('Cloud')),
                DropdownMenuItem<String>(
                  value: 'desktop',
                  child: Text('Desktop app'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _cliBackend = value);
                }
              },
            ),
            if (_cliBackend == 'desktop' && controller.desktopDevices.length > 1) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: controller.desktopDevices.any(
                  (d) => d['deviceId']?.toString() == _cliDesktopDeviceId,
                )
                    ? _cliDesktopDeviceId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Desktop device',
                  helperText: 'Choose which desktop companion runs CLI commands.',
                ),
                items: controller.desktopDevices.map((device) {
                  final deviceId = device['deviceId']?.toString() ?? '';
                  final label = device['hostname']?.toString().isNotEmpty == true
                      ? device['hostname']!.toString()
                      : deviceId;
                  final online = device['online'] == true;
                  return DropdownMenuItem<String>(
                    value: deviceId,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          online ? Icons.circle : Icons.circle_outlined,
                          size: 10,
                          color: online ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _cliDesktopDeviceId = value);
                  }
                },
              ),
            ],
            const SizedBox(height: 10),
            _buildInlineTestRow(
              label: 'CLI',
              running: _cliTestRunning,
              result: _cliTestResult,
              note: _cliBackend == 'desktop'
                  ? (controller.desktopCompanionConnected
                      ? 'Desktop app connected — commands route locally through the companion.'
                      : 'Desktop app selected but not connected. Commands fall back to cloud VM until the companion is online.')
                  : 'Cloud VM — commands run in an isolated container.',
              onTest: () async {
                setState(() { _cliTestRunning = true; _cliTestResult = null; });
                try {
                  final r = await controller.testCliRuntime();
                  if (mounted) {
                    setState(() => _cliTestResult = r);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _cliTestResult = <String, dynamic>{'passed': false, 'detail': e.toString()});
                  }
                } finally {
                  if (mounted) {
                    setState(() => _cliTestRunning = false);
                  }
                }
              },
            ),
            const Divider(height: 32),
            Text(
              'Routing Behavior',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _SettingToggle(
              title: 'Smart model selection',
              subtitle:
                  'Automatically choose the best enabled model for each task type.',
              value: _smarterSelector,
              onChanged: (value) => setState(() => _smarterSelector = value),
            ),
          ],
        ),
      ),
    );
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
                          ),
                          options: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _defaultChatModel = value);
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
                          ),
                          options: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _defaultSubagentModel = value);
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
                              setState(() => _fallbackModel = value);
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
                    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  ),
                  pageBuilder: (ctx, _, __) => _SmartPoolDialog(
                    models: controller.supportedModels,
                    selectedIds: _enabledModels,
                  ),
                );
                if (result != null) setState(() => _enabledModels = result);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAndRecordingSection({
    required NeoAgentController controller,
    required List<_ModelPickerOption> modelChoices,
    required List<ModelMeta> routingModels,
  }) {
    final liveVoiceOptions =
        _voiceLiveVoicesByProvider[_voiceLiveProvider] ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Voice & Recording'),
            const SizedBox(height: 10),
            Text(
              'Defaults for transcription, summaries, and live voice.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Recording Defaults',
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
                        label: 'Recording Summary',
                        icon: Icons.summarize_outlined,
                        value: _ensureModelValue(
                          _defaultRecordingSummaryModel,
                          routingModels,
                          allowAuto: true,
                        ),
                        options: modelChoices,
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _defaultRecordingSummaryModel = value,
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Recording Transcription',
                        icon: Icons.hearing_outlined,
                        value: _defaultRecordingTranscriptionModel,
                        options: _recordingTranscriptionOptions(
                          _defaultRecordingTranscriptionModel,
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _defaultRecordingTranscriptionModel = value;
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
                        ),
                        options: modelChoices,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _defaultSpeechModel = value);
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
              'Live Voice',
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
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Live Provider',
                        icon: Icons.call_outlined,
                        value: _voiceLiveProvider,
                        options: _simplePickerOptions(
                          const <String>['openai', 'gemini'],
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceLiveProvider = value;
                            final modelOptions =
                                _voiceLiveModelsByProvider[_voiceLiveProvider] ??
                                const <String>[];
                            if (!modelOptions.contains(_voiceLiveModel) &&
                                modelOptions.isNotEmpty) {
                              _voiceLiveModel = modelOptions.first;
                            }
                            final voiceOptions =
                                _voiceLiveVoicesByProvider[_voiceLiveProvider] ??
                                const <String>[];
                            if (voiceOptions.isNotEmpty &&
                                !voiceOptions.contains(_voiceLiveVoice)) {
                              _voiceLiveVoice = voiceOptions.first;
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Live Model',
                        icon: Icons.speed_outlined,
                        value: _voiceLiveModel,
                        options: _simplePickerOptions(
                          _voiceLiveModelsByProvider[_voiceLiveProvider] ??
                              const <String>[],
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _voiceLiveModel = value);
                          }
                        },
                      ),
                    ),
                    if (liveVoiceOptions.isNotEmpty)
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Live Voice',
                          icon: Icons.graphic_eq_outlined,
                          value: _voiceLiveVoice,
                          options: _simplePickerOptions(liveVoiceOptions),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _voiceLiveVoice = value);
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
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
            const _SectionTitle('Desktop'),
            const SizedBox(height: 10),
            Text(
              'Desktop-only recording and companion controls for this computer.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Local App Behavior',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: controller.desktopAskOnClose,
              contentPadding: EdgeInsets.zero,
              title: Text('Ask before closing to background'),
              subtitle: Text(
                'Prompt for whether NeoAgent should stay resident in the tray when the main window closes.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: (value) => controller.setDesktopClosePreference(
                askOnClose: value,
                keepRunningOnClose: controller.desktopKeepRunningOnClose,
              ),
            ),
            SwitchListTile.adaptive(
              value: controller.desktopAutoShowFloatingToolbar,
              contentPadding: EdgeInsets.zero,
              title: Text('Auto-show floating toolbar'),
              subtitle: Text(
                'Open the compact recording bar automatically whenever a desktop studio session starts.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.setDesktopAutoShowFloatingToolbar,
            ),
            SwitchListTile.adaptive(
              value: controller.desktopAssistantHotkeyEnabled,
              contentPadding: EdgeInsets.zero,
              title: Text('Reserve assistant hotkey'),
              subtitle: Text(
                'Register $_desktopAssistantHotkeyLabel so the desktop shell is ready for the upcoming voice assistant summon flow.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.recordingRuntime.supportsGlobalHotkeys
                  ? controller.setDesktopAssistantHotkeyEnabled
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _RecordingPermissionBadge(
                  label: 'Microphone',
                  state: controller.recordingRuntime.microphonePermission,
                ),
                _RecordingPermissionBadge(
                  label: 'System audio',
                  state: controller.recordingRuntime.systemAudioPermission,
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Companion Mode',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: controller.desktopCompanionEnabled,
              contentPadding: EdgeInsets.zero,
              title: Text('Enable Companion Mode on this computer'),
              subtitle: Text(
                'Expose this signed-in desktop app as a controllable companion device without a separate pairing flow.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.setDesktopCompanionEnabled,
            ),
            SwitchListTile.adaptive(
              value: controller.desktopCompanionPaused,
              contentPadding: EdgeInsets.zero,
              title: Text('Pause Companion Mode'),
              subtitle: Text(
                'Keep the device registered but reject remote control commands locally until resumed.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.desktopCompanionEnabled
                  ? controller.setDesktopCompanionPaused
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: controller.desktopCompanionLabel,
              enabled: controller.desktopCompanionEnabled,
              decoration: const InputDecoration(
                labelText: 'Companion device label',
                hintText: 'My workstation',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              onFieldSubmitted: controller.setDesktopCompanionLabel,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DotStatus(
                  label: controller.desktopCompanionConnected
                      ? 'Connected'
                      : controller.desktopCompanionConnecting
                      ? 'Connecting'
                      : 'Disconnected',
                  color: controller.desktopCompanionConnected
                      ? _success
                      : controller.desktopCompanionConnecting
                      ? _accent
                      : _warning,
                ),
                _DotStatus(
                  label: controller.desktopCompanionPaused ? 'Paused' : 'Ready',
                  color: controller.desktopCompanionPaused
                      ? _warning
                      : _success,
                ),
              ],
            ),
            if (controller.desktopCompanionErrorMessage
                case final message?) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: message),
            ],
            const SizedBox(height: 12),
            _buildInlineTestRow(
              label: 'Desktop companion',
              running: _desktopTestRunning,
              result: _desktopTestResult != null
                  ? <String, dynamic>{
                      'passed': _desktopTestResult!['passed'] == true,
                      'detail': _desktopTestResult!['detail']?.toString() ?? '',
                    }
                  : null,
              note: controller.desktopCompanionConnected
                  ? 'Connected — tap Test to fetch live device status from the server.'
                  : 'Not connected. Make sure the desktop app is running on the target machine.',
              onTest: () async {
                setState(() { _desktopTestRunning = true; _desktopTestResult = null; });
                try {
                  final r = await controller.testDesktopCompanion();
                  final active = r['activeDevice'];
                  final multi = r['multipleOnline'] == true;
                  String detail = r['detail']?.toString() ?? '';
                  if (r['passed'] == true && active != null) {
                    final label = active['label']?.toString() ?? 'Device';
                    final plat = active['platform']?.toString() ?? '';
                    final sc = active['permissions']?['screenCapture'] == true;
                    final ic = active['permissions']?['inputControl'] == true;
                    detail = '$label${plat.isNotEmpty ? " ($plat)" : ""}'
                        ' — screen: ${sc ? "✓" : "✗"}, input: ${ic ? "✓" : "✗"}';
                  } else if (multi) {
                    detail = '${r['onlineCount']} devices online — select one in Desktop › Devices';
                  }
                  if (mounted) {
                    setState(() => _desktopTestResult = <String, dynamic>{
                      ...r,
                      'detail': detail,
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _desktopTestResult = <String, dynamic>{'passed': false, 'detail': e.toString()});
                  }
                } finally {
                  if (mounted) {
                    setState(() => _desktopTestRunning = false);
                  }
                }
              },
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final status = controller.desktopCompanionStatus;
                final permissionsRaw = status['permissions'];
                final permissions = permissionsRaw is Map
                    ? permissionsRaw.map(
                        (key, value) => MapEntry(
                          key.toString(),
                          value?.toString() ?? 'unknown',
                        ),
                      )
                    : const <String, String>{};
                final screenCaptureState =
                    permissions['screenCapture'] ?? 'unknown';
                final inputControlState =
                    permissions['inputControl'] ?? 'unknown';
                final accessibilityState =
                    permissions['accessibility'] ?? 'unknown';
                final grantHelp = switch (defaultTargetPlatform) {
                  TargetPlatform.macOS =>
                    'Grant Screen Recording and Accessibility in System Settings, then press Re-check.',
                  TargetPlatform.windows =>
                    'Grant capture and accessibility/input permissions in Windows Settings, then press Re-check.',
                  TargetPlatform.linux =>
                    'Approve portal capture/input prompts and desktop accessibility access, then press Re-check.',
                  TargetPlatform.android ||
                  TargetPlatform.iOS ||
                  TargetPlatform.fuchsia =>
                    'Desktop companion permission controls are unavailable on this platform.',
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      grantHelp,
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _CompanionPermissionBadge(
                          label: 'Screen capture',
                          state: screenCaptureState,
                        ),
                        _CompanionPermissionBadge(
                          label: 'Input control',
                          state: inputControlState,
                        ),
                        _CompanionPermissionBadge(
                          label: 'Accessibility',
                          state: accessibilityState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? controller.refreshDesktopCompanionStatus
                              : null,
                          icon: Icon(Icons.sync_outlined),
                          label: Text('Re-check permissions'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? () => controller
                                    .openDesktopCompanionPermissionSettings(
                                      'screenCapture',
                                    )
                              : null,
                          icon: Icon(Icons.monitor_outlined),
                          label: Text('Open capture settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? () => controller
                                    .openDesktopCompanionPermissionSettings(
                                      'accessibility',
                                    )
                              : null,
                          icon: Icon(Icons.keyboard_command_key_outlined),
                          label: Text('Open input/access settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? controller.rotateDesktopCompanionIdentity
                              : null,
                          icon: Icon(Icons.refresh_outlined),
                          label: Text('Reset Device Identity'),
                        ),
                      ],
                    ),
                  ],
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
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _providerForSelectedModel(String modelId, List<ModelMeta> models) {
    if (modelId.trim().isEmpty || modelId == 'auto') {
      return 'auto';
    }
    for (final model in models) {
      if (model.id == modelId) {
        return model.provider.trim().isEmpty ? 'auto' : model.provider;
      }
    }
    return 'auto';
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

  List<_ModelPickerOption> _recordingTranscriptionOptions(String current) {
    const List<String> defaults = <String>['nova-3', 'nova-2-general'];
    final String normalizedCurrent = current.trim();
    final Set<String> values = <String>{...defaults};
    if (normalizedCurrent.isNotEmpty) values.add(normalizedCurrent);
    return _simplePickerOptions(values.toList());
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
                      passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 15,
                      color: passed ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        passed ? (detail.isNotEmpty ? detail : '$label: OK') : detail,
                        style: TextStyle(
                          fontSize: 13,
                          color: passed ? null : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                )
              else if (note != null)
                Text(note, style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.4)),
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
                      ...providers.take(12).map(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  const _SmartPoolDialog({
    required this.models,
    required this.selectedIds,
  });

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
          .where((m) =>
              m.label.toLowerCase().contains(q) ||
              m.id.toLowerCase().contains(q) ||
              m.provider.toLowerCase().contains(q))
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
      _selected = remaining.isNotEmpty
          ? remaining
          : <String>{_selected.first};
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
      final allGroupSelected = available.isNotEmpty &&
          available.every((m) => _selected.contains(m.id));

      rows.add(Padding(
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
                          final toRemove =
                              available.map((m) => m.id).toSet();
                          final remaining =
                              _selected.difference(toRemove);
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
      ));

      for (final model in models) {
        rows.add(_SmartPoolRow(
          model: model,
          selected: _selected.contains(model.id),
          onToggle: (val) => setState(() {
            if (val) {
              _selected.add(model.id);
            } else if (_selected.length > 1) {
              _selected.remove(model.id);
            }
          }),
        ));
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
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                                    vertical: 10),
                                filled: true,
                                fillColor: _bgSecondary,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: _border),
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
                                () => _onlyAvailable = !_onlyAvailable),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                            ),
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
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 8),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: <Widget>[
                // Thin provider accent bar on the left
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(
                        alpha: selected ? 0.85 : 0.28),
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
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
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
                          color:
                              selected ? _accentHover : _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (model.purpose.isNotEmpty)
                        Text(
                          model.purpose,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textMuted,
                          ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
