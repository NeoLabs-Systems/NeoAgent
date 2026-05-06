part of 'main.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

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

class _SettingsPanelState extends State<SettingsPanel> {
  late bool _headlessBrowser;
  late String _browserBackend;
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
  final Set<String> _expandedProviderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
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
    _headlessBrowser = controller.headlessBrowser;
    _browserBackend = _normalizeBrowserBackend(controller.browserBackend);
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
    return normalized == 'extension' ? 'extension' : 'cloud';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final modelChoices = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'auto',
        child: Text('Smart Selector (Auto)'),
      ),
      ...routingModels.map(
        (model) =>
            DropdownMenuItem<String>(value: model.id, child: Text(model.label)),
      ),
    ];
    final enabledSmartModels = _enabledModels
        .where((id) => routingModels.any((model) => model.id == id))
        .length;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Settings',
          subtitle:
              'Workspace, models, recording, update, and diagnostics controls.',
          trailing: FilledButton.icon(
            onPressed: controller.isSavingSettings
                ? null
                : () => controller.saveSettings(
                    headlessBrowser: _headlessBrowser,
                    browserBackend: _browserBackend == 'extension'
                        ? 'extension'
                        : controller.cloudBrowserBackend,
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
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildSettingsOverview(controller, availableModels.length),
        const SizedBox(height: 16),
        _buildManagementSection(controller),
        const SizedBox(height: 16),
        _buildWorkspaceSection(controller),
        const SizedBox(height: 16),
        _buildModelsSection(
          controller: controller,
          modelChoices: modelChoices,
          routingModels: routingModels,
          availableModels: availableModels,
          enabledSmartModels: enabledSmartModels,
        ),
        const SizedBox(height: 16),
        _buildVoiceAndRecordingSection(
          controller: controller,
          modelChoices: modelChoices,
          routingModels: routingModels,
        ),
        const SizedBox(height: 16),
        if (_supportsDesktopShell) ...<Widget>[
          _buildDesktopSection(controller),
          const SizedBox(height: 16),
        ],
        _buildUpdatesSection(controller),
        const SizedBox(height: 16),
        _buildDiagnosticsSection(controller),
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
              'Configure workspace behavior, then models, recording defaults, and updates.',
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
            _SettingToggle(
              title: 'Run browser headless',
              subtitle:
                  'Keep browser automation off-screen when visible windows are not needed.',
              value: _headlessBrowser,
              onChanged: (value) => setState(() => _headlessBrowser = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _browserBackend,
              decoration: const InputDecoration(
                labelText: 'Browser backend',
                helperText:
                    'Cloud uses this deployment. Extension uses a paired Chrome browser.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'cloud',
                  child: Text('Cloud (local)'),
                ),
                DropdownMenuItem<String>(
                  value: 'extension',
                  child: Text('Chrome extension'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _browserBackend = value);
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              _browserBackend == 'extension'
                  ? (controller.browserExtensionConnected
                        ? 'Chrome extension connected.'
                        : 'Chrome extension selected. Download it here, load it unpacked in Chrome on the remote machine, then pair after login.')
                  : controller.cloudBrowserBackend == 'vm'
                  ? "Cloud uses this deployment's isolated VM browser runtime."
                  : "Cloud uses this deployment's local host browser runtime.",
              style: TextStyle(color: _textSecondary, height: 1.4),
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
                  label: Text('Refresh status'),
                ),
              ],
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

  Widget _buildManagementSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Subcategories'),
            const SizedBox(height: 10),
            Text(
              'Open settings areas that have their own dedicated management screens.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => controller.setSelectedSection(AppSection.agents),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                decoration: BoxDecoration(
                  color: _bgSecondary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _accentMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          color: _accentHover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Agents',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage specialist agents, routing roles, memory separation, and account assignment.',
                              style: TextStyle(
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.chevron_right_rounded, color: _textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelsSection({
    required NeoAgentController controller,
    required List<DropdownMenuItem<String>> modelChoices,
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
              'Enable providers, then choose defaults for chat, agents, fallback behavior, and smart routing.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Providers',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (controller.aiProviders.isEmpty)
              Text(
                'Provider metadata is unavailable on this server version.',
                style: TextStyle(color: _textSecondary),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 960;
                  final cardWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: controller.aiProviders
                        .where(
                          (provider) =>
                              provider.available ||
                              _providerEnabled[provider.id] == true ||
                              controller
                                      .aiProviderConfigs[provider.id]
                                      ?.enabled ==
                                  true,
                        )
                        .map((provider) {
                          return SizedBox(
                            width: cardWidth,
                            child: _AiProviderCard(
                              provider: provider,
                              enabled:
                                  _providerEnabled[provider.id] ??
                                  controller
                                      .aiProviderConfigs[provider.id]
                                      ?.enabled ??
                                  true,
                              models: controller.supportedModels
                                  .where(
                                    (model) => model.provider == provider.id,
                                  )
                                  .toList(),
                              baseUrlController:
                                  _providerBaseUrlControllers[provider.id]!,
                              expanded: _expandedProviderIds.contains(
                                provider.id,
                              ),
                              onEnabledChanged: (value) {
                                setState(() {
                                  _providerEnabled[provider.id] = value;
                                });
                              },
                              onExpandToggle: () {
                                setState(() {
                                  if (_expandedProviderIds.contains(
                                    provider.id,
                                  )) {
                                    _expandedProviderIds.remove(provider.id);
                                  } else {
                                    _expandedProviderIds.add(provider.id);
                                  }
                                });
                              },
                            ),
                          );
                        })
                        .toList(),
                  );
                },
              ),
            const Divider(height: 32),
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
                          items: modelChoices,
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
                          items: modelChoices,
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
                          items: routingModels
                              .map(
                                (model) => DropdownMenuItem<String>(
                                  value: model.id,
                                  child: Text(model.label),
                                ),
                              )
                              .toList(),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: controller.supportedModels.map((model) {
                final selected = _enabledModels.contains(model.id);
                return FilterChip(
                  label: Text(
                    model.available
                        ? model.label
                        : '${model.label} (${model.providerStatusLabel})',
                  ),
                  selected: selected,
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(
                    color: model.available
                        ? _border
                        : _warning.withValues(alpha: 0.35),
                  ),
                  onSelected: model.available
                      ? (value) {
                          setState(() {
                            if (value) {
                              _enabledModels.add(model.id);
                            } else if (_enabledModels.length > 1) {
                              _enabledModels.remove(model.id);
                            }
                          });
                        }
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              availableModels.isEmpty
                  ? 'Enable a ready provider above to unlock model routing.'
                  : '$enabledSmartModels models are currently eligible for smart routing.',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAndRecordingSection({
    required NeoAgentController controller,
    required List<DropdownMenuItem<String>> modelChoices,
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
                        items: modelChoices,
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
                        items: _recordingTranscriptionModelChoices(
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
                        items: modelChoices,
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
                        items: const <String>['openai', 'gemini']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
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
                        items:
                            (_voiceLiveModelsByProvider[_voiceLiveProvider] ??
                                    const <String>[])
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
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
                          items: liveVoiceOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
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

  Widget _buildUpdatesSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Updates'),
            const SizedBox(height: 10),
            Text(
              'Client and runtime update controls live here.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final checkButton = FilledButton.icon(
                  onPressed:
                      controller.isCheckingAppUpdate ||
                          !controller.appUpdaterConfigured
                      ? null
                      : () => controller.checkForAppUpdates(),
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  icon: controller.isCheckingAppUpdate
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    controller.isCheckingAppUpdate
                        ? 'Checking...'
                        : 'Check now',
                  ),
                );
                final appHeading = Text(
                  'Client App',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      appHeading,
                      const SizedBox(height: 10),
                      checkButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: appHeading),
                    checkButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (!controller.appUpdaterConfigured)
              Text(
                kIsWeb
                    ? 'Client app update checks are disabled in the web app to avoid blocked browser-side GitHub requests.'
                    : 'Client app updates are not configured for this build.',
                style: TextStyle(color: _textSecondary, height: 1.5),
              )
            else ...<Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final channelPicker = DropdownButtonFormField<String>(
                    initialValue: controller.appUpdateChannel,
                    decoration: const InputDecoration(
                      labelText: 'App release channel',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'stable',
                        child: Text('Stable'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'beta',
                        child: Text('Beta'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        unawaited(controller.setAppUpdateChannel(value));
                      }
                    },
                  );
                  final autoCheck = SwitchListTile.adaptive(
                    value: controller.appUpdateAutoCheckEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Check automatically on launch'),
                    subtitle: Text(
                      'This only checks GitHub Releases on startup. Installation still requires your confirmation.',
                      style: TextStyle(color: _textSecondary),
                    ),
                    onChanged: controller.setAppUpdateAutoCheckEnabled,
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        channelPicker,
                        const SizedBox(height: 10),
                        autoCheck,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: channelPicker),
                      const SizedBox(width: 16),
                      Expanded(child: autoCheck),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Installed: ${controller.installedAppVersion ?? 'Unknown'} | Channel: ${controller.appUpdateChannelLabel} | Last checked: ${controller.appUpdateLastCheckedLabel}',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Source: ${app_release_updater.appUpdaterGithubOwner}/${app_release_updater.appUpdaterGithubRepo}${app_release_updater.appUpdaterGithubToken.trim().isNotEmpty ? ' (override active)' : ''}',
                style: TextStyle(color: _textSecondary),
              ),
              if (controller.appUpdateErrorMessage
                  case final message?) ...<Widget>[
                const SizedBox(height: 12),
                _InlineError(message: message),
              ],
              if (controller.availableAppUpdate
                  case final release?) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _StatusPill(
                            label: 'Update ${release.version}',
                            color: release.channel == 'beta'
                                ? _warning
                                : _accent,
                          ),
                          _StatusPill(
                            label: release.asset.name,
                            color: _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${release.title} · ${release.publishedLabel} · ${release.asset.sizeLabel}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (release.body.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: MarkdownBody(
                              data: release.body,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: _textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: controller.isOpeningAppUpdate
                                ? null
                                : controller.openAppUpdate,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                            ),
                            icon: controller.isOpeningAppUpdate
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.system_update_alt),
                            label: Text(
                              controller.isOpeningAppUpdate
                                  ? 'Opening...'
                                  : 'Download update',
                            ),
                          ),
                          if (release.htmlUrl.trim().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                unawaited(
                                  widget.controller._oauthLauncher.openExternal(
                                    url: release.htmlUrl,
                                    label: 'release_notes',
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: Text('View release'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  controller.isCheckingAppUpdate
                      ? 'Checking GitHub releases...'
                      : controller.appUpdateLastCheckedAt == null
                      ? 'Choose a channel, then check GitHub releases.'
                      : 'No newer app release is available on the selected channel.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
              ],
            ],
            const Divider(height: 32),
            if (controller.updateStatus.allowSelfUpdate) ...<Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final channelPicker = DropdownButtonFormField<String>(
                    initialValue: controller.updateStatus.releaseChannel,
                    decoration: const InputDecoration(
                      labelText: 'Runtime release channel',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'stable',
                        child: Text('Stable'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'beta',
                        child: Text('Beta'),
                      ),
                    ],
                    onChanged:
                        controller.isSavingReleaseChannel ||
                            controller.isTriggeringUpdate ||
                            controller.updateStatus.state == 'running'
                        ? null
                        : (value) {
                            if (value != null) {
                              unawaited(controller.setReleaseChannel(value));
                            }
                          },
                  );

                  final channelHelper = Text(
                    controller.updateStatus.releaseChannel == 'beta'
                        ? 'Beta follows preview releases.'
                        : 'Stable follows production releases.',
                    style: TextStyle(color: _textSecondary),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        channelPicker,
                        const SizedBox(height: 8),
                        channelHelper,
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: channelPicker),
                        const SizedBox(width: 12),
                        Expanded(child: channelHelper),
                      ],
                    ),
                  );
                },
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final runtimeTitle = Text(
                    'Runtime',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  );
                  final updateButton = FilledButton.icon(
                    onPressed:
                        controller.isSavingReleaseChannel ||
                            controller.isTriggeringUpdate ||
                            controller.updateStatus.state == 'running'
                        ? null
                        : controller.triggerUpdate,
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    icon: controller.isTriggeringUpdate
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.system_update),
                    label: Text('Update'),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        runtimeTitle,
                        const SizedBox(height: 10),
                        updateButton,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: runtimeTitle),
                      updateButton,
                    ],
                  );
                },
              ),
            ] else ...<Widget>[
              Text(
                'Runtime',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Updates and release tracks are managed for this deployment.',
                style: TextStyle(color: _textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final statusRow = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _StatusPill(
                      label: controller.updateStatus.badgeLabel,
                      color: controller.updateStatus.badgeColor,
                    ),
                    _StatusPill(
                      label: controller.updateStatus.releaseChannelLabel,
                      color: controller.updateStatus.releaseChannel == 'beta'
                          ? _warning
                          : _accent,
                    ),
                    Text(
                      controller.updateStatus.message,
                      style: TextStyle(color: _textSecondary),
                    ),
                    Text('${controller.updateStatus.progress}%'),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[statusRow],
                  );
                }
                return statusRow;
              },
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: controller.updateStatus.progress / 100,
                backgroundColor: _bgSecondary,
                color: _accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(controller.updateStatus.versionLine),
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

  List<DropdownMenuItem<String>> _recordingTranscriptionModelChoices(
    String current,
  ) {
    const defaults = <String>['nova-3', 'nova-2-general'];
    final normalizedCurrent = current.trim();
    final values = <String>{...defaults};
    if (normalizedCurrent.isNotEmpty) {
      values.add(normalizedCurrent);
    }
    return values
        .map(
          (value) => DropdownMenuItem<String>(value: value, child: Text(value)),
        )
        .toList();
  }
}

class _AiProviderCard extends StatelessWidget {
  const _AiProviderCard({
    required this.provider,
    required this.enabled,
    required this.expanded,
    required this.models,
    required this.baseUrlController,
    required this.onEnabledChanged,
    required this.onExpandToggle,
  });

  final AiProviderMeta provider;
  final bool enabled;
  final bool expanded;
  final List<ModelMeta> models;
  final TextEditingController baseUrlController;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onExpandToggle;

  @override
  Widget build(BuildContext context) {
    final availableCount = models.where((model) => model.available).length;
    final hasAdvancedFields = provider.supportsBaseUrl || models.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(provider.icon, color: _accentHover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _StatusPill(
                    label: enabled ? provider.statusLabel : 'Disabled',
                    color: enabled ? provider.statusColor : _textSecondary,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: hasAdvancedFields || models.isNotEmpty
                        ? onExpandToggle
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            expanded ? 'Hide' : 'Setup',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: _textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                label: '$availableCount of ${models.length} models ready',
                icon: Icons.memory_outlined,
              ),
              if (provider.supportsApiKey && provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials ready',
                  icon: Icons.lock_outline,
                ),
              if (provider.supportsApiKey && !provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials needed',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              if (provider.supportsBaseUrl &&
                  baseUrlController.text.trim().isNotEmpty)
                _MetaPill(
                  label: _friendlyBaseUrlLabel(baseUrlController.text.trim()),
                  icon: Icons.link_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    provider.availabilityReason,
                    style: TextStyle(color: _textSecondary, height: 1.35),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 14),
            if (provider.supportsApiKey)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  provider.credentialConfigured
                      ? 'Credentials for this provider are already available to the runtime.'
                      : 'Credentials for this provider are managed outside this workspace UI. Finish the server or admin setup, then return here to enable routing.',
                  style: TextStyle(color: _textSecondary, height: 1.35),
                ),
              ),
            if (provider.supportsBaseUrl) ...<Widget>[
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: provider.id == 'ollama'
                      ? 'Server URL'
                      : 'Base URL',
                  helperText: provider.defaultBaseUrl.trim().isEmpty
                      ? 'Optional override.'
                      : 'Default: ${provider.defaultBaseUrl}',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (models.isNotEmpty) ...<Widget>[
              Text('Models', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: models
                    .map(
                      (model) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: model.available ? _bgCard : _bgPrimary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: model.available ? _border : _borderLight,
                          ),
                        ),
                        child: Text(
                          model.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: model.available
                                ? _textPrimary
                                : _textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
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
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
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
          DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            decoration: const InputDecoration(isDense: true),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
