part of 'main.dart';

/// Settings › Models: the agent's default models, smart selection and the
/// API keys that pay for them.
class _ModelsSettingsPage extends StatelessWidget {
  const _ModelsSettingsPage({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final modelChoices = _modelPickerOptions(routingModels, allowAuto: true);
    final systemOneModels = controller.systemOneModels
        .where((model) => model.available)
        .toList();
    // An empty saved pool means every available model is in it.
    final pool = controller.enabledModelIds.isEmpty
        ? availableModels.map((model) => model.id).toSet()
        : controller.enabledModelIds.toSet();
    final poolSize = availableModels
        .where((model) => pool.contains(model.id))
        .length;

    _SettingsRow modelRow({
      required String anchor,
      required String label,
      required String description,
      required String value,
      required String settingKey,
    }) {
      return _SettingsRow(
        anchor: anchor,
        label: label,
        description: description,
        fillControl: true,
        control: _ModelPickerButton(
          value: _ensureModelValue(
            value,
            routingModels,
            allowAuto: true,
            preserveUnknown: true,
          ),
          options: modelChoices,
          dialogTitle: appStrings.selectArg1(label),
          onChanged: (next) {
            if (next != null) {
              _autosaveSettings(controller, <String, dynamic>{
                settingKey: next,
              });
            }
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (availableModels.isEmpty && !controller.isRefreshing) ...<Widget>[
          _InlineError(
            message:
                appStrings.noAiProviderIsConfiguredSo + appStrings.cannotRunYet,
          ),
          const SizedBox(height: 20),
        ],
        _SettingsGroup(
          title: appStrings.settingsDefaultModels,
          description: appStrings.settingsDefaultModelsDescription,
          children: <Widget>[
            modelRow(
              anchor: 'chatModel',
              label: appStrings.settingsChatModel,
              description: appStrings.settingsChatModelDescription,
              value: controller.defaultChatModel,
              settingKey: 'default_chat_model',
            ),
            _SettingsRow(
              anchor: 'systemOne',
              label: appStrings.systemOneModels,
              description: systemOneModels.isEmpty
                  ? appStrings.noSystemOneModelIsAvailableYet
                  : appStrings.systemOneModelsMakeTheBehindTheScenes,
              fillControl: true,
              control: _ModelPickerButton(
                value: _ensureModelValue(
                  controller.systemOneModel,
                  systemOneModels,
                  allowAuto: true,
                  preserveUnknown: true,
                ),
                options: <_ModelPickerOption>[
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
                  ..._modelPickerOptions(systemOneModels),
                ],
                dialogTitle: appStrings.selectArg1(appStrings.systemOneModels),
                onChanged: (next) {
                  if (next != null) {
                    _autosaveSettings(controller, <String, dynamic>{
                      'system_one_model': next,
                    });
                  }
                },
              ),
            ),
          ],
        ),
        _AdvancedModelSettings(controller: controller, models: routingModels),
        _SettingsGroup(
          title: appStrings.settingsSmartSelection,
          children: <Widget>[
            _SettingsRow(
              anchor: 'smartSelection',
              label: appStrings.smartModelSelection,
              description: appStrings.automaticallyChooseTheBestEnabledModel,
              control: Switch(
                value: controller.smarterSelector,
                onChanged: (value) => _autosaveSettings(
                  controller,
                  <String, dynamic>{'smarter_model_selector': value},
                ),
              ),
            ),
            _SettingsRow(
              anchor: 'modelPool',
              label: appStrings.settingsModelPool,
              description: appStrings.arg1OfArg2Models(
                poolSize,
                availableModels.length,
              ),
              enabled: controller.smarterSelector,
              control: OutlinedButton.icon(
                onPressed: () => _managePool(context, pool),
                icon: Icon(Icons.tune_rounded, size: 16),
                label: Text(appStrings.manage),
              ),
            ),
          ],
        ),
        _ByokSettingsCard(controller: controller),
      ],
    );
  }

  Future<void> _managePool(BuildContext context, Set<String> pool) async {
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
      pageBuilder: (ctx, _, _) => _SmartPoolDialog(
        models: controller.supportedModels,
        selectedIds: pool,
      ),
    );
    if (result != null) {
      _autosaveSettings(controller, <String, dynamic>{
        'enabled_models': result.toList(),
      });
    }
  }
}

/// Optional per-task model pins, collapsed by default. A task left on
/// "Default" follows the chat or sub-agent model, so nothing here is required.
class _AdvancedModelSettings extends StatefulWidget {
  const _AdvancedModelSettings({
    required this.controller,
    required this.models,
  });

  final NeoAgentController controller;
  final List<ModelMeta> models;

  @override
  State<_AdvancedModelSettings> createState() => _AdvancedModelSettingsState();
}

class _AdvancedModelSettingsState extends State<_AdvancedModelSettings> {
  late bool _expanded = widget.controller.taskModels.isNotEmpty;

  static List<(String, String Function(), String Function())> get _tasks =>
      <(String, String Function(), String Function())>[
        (
          'coding',
          () => appStrings.settingsTaskModelCoding,
          () => appStrings.settingsTaskModelCodingDescription,
        ),
        (
          'computer_use',
          () => appStrings.settingsTaskModelComputerUse,
          () => appStrings.settingsTaskModelComputerUseDescription,
        ),
        (
          'android_use',
          () => appStrings.settingsTaskModelAndroidUse,
          () => appStrings.settingsTaskModelAndroidUseDescription,
        ),
        (
          'research',
          () => appStrings.settingsTaskModelResearch,
          () => appStrings.settingsTaskModelResearchDescription,
        ),
      ];

  void _pin(String kind, String? value) {
    if (value == null) return;
    final next = Map<String, String>.from(widget.controller.taskModels);
    if (value.isEmpty) {
      next.remove(kind);
    } else {
      next[kind] = value;
    }
    _autosaveSettings(widget.controller, <String, dynamic>{
      'task_models': next,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinned = widget.controller.taskModels;
    final options = <_ModelPickerOption>[
      _ModelPickerOption(
        value: '',
        label: appStrings.settingsTaskModelDefault,
        subtitle: appStrings.settingsTaskModelDefaultSubtitle,
        icon: Icons.auto_awesome_outlined,
        isAuto: true,
      ),
      ..._modelPickerOptions(widget.models),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      appStrings.settingsAdvancedModels,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (pinned.isNotEmpty && !_expanded)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${pinned.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                        child: Text(
                          appStrings.settingsAdvancedModelsDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _SettingsCardList(
                        children: <Widget>[
                          for (final (kind, label, description) in _tasks)
                            _SettingsRow(
                              anchor: 'taskModel_$kind',
                              label: label(),
                              description: description(),
                              fillControl: true,
                              control: _ModelPickerButton(
                                value: pinned[kind] ?? '',
                                options: options,
                                dialogTitle: appStrings.selectArg1(label()),
                                onChanged: (next) => _pin(kind, next),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Settings › Behavior: the agent's persona notes and how it reads a group.
class _BehaviorSettingsPage extends StatefulWidget {
  const _BehaviorSettingsPage({required this.controller});

  final NeoAgentController controller;

  @override
  State<_BehaviorSettingsPage> createState() => _BehaviorSettingsPageState();
}

class _BehaviorSettingsPageState extends State<_BehaviorSettingsPage> {
  static const Set<String> _fineTuningAnchors = <String>{
    'turnTaking',
    'minimumNeed',
    'batchWindow',
  };

  bool _showFineTuning = false;

  /// Slider positions while dragging; saved when the drag ends.
  double? _draftNeedScore;
  double? _draftBatchWindow;

  NeoAgentController get _controller => widget.controller;
  Map<String, dynamic> get _behavior => _controller.behaviorConfig;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A search for a fine-tuning setting opens the section it lives in.
    final highlight = _SettingsHighlightScope.of(context);
    if (highlight != null && _fineTuningAnchors.contains(highlight.anchor)) {
      _showFineTuning = true;
    }
  }

  bool _moduleEnabled(String id) {
    final modules = _behavior['modules'];
    final module = modules is Map ? modules[id] : null;
    return module is! Map || module['enabled'] != false;
  }

  void _update(Map<String, dynamic> patch) {
    unawaited(_controller.updateBehaviorConfig(patch));
  }

  void _setModule(String id, bool enabled) {
    final modules = _behavior['modules'] is Map
        ? Map<String, dynamic>.from(_behavior['modules'] as Map)
        : <String, dynamic>{};
    final module = modules[id] is Map
        ? Map<String, dynamic>.from(modules[id] as Map)
        : <String, dynamic>{};
    modules[id] = <String, dynamic>{...module, 'enabled': enabled};
    _update(<String, dynamic>{'modules': modules});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final enabled = _behavior['enabled'] != false;
    final needScore =
        _draftNeedScore ??
        ((_behavior['minimumNeedScore'] as num?)?.toDouble() ?? 0.58)
            .clamp(0.0, 1.0)
            .toDouble();
    final batchWindow =
        _draftBatchWindow ??
        ((_behavior['batchWindowMs'] as num?)?.toDouble() ?? 900)
            .clamp(0.0, 5000.0)
            .toDouble();
    final decisionModel = _behavior['decisionModelId']?.toString().trim() ?? '';
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;

    Widget moduleRow(String anchor, String label, String module) {
      return _SettingsRow(
        anchor: anchor,
        label: label,
        enabled: enabled,
        control: Switch(
          value: _moduleEnabled(module),
          onChanged: (value) => _setModule(module, value),
        ),
      );
    }

    Widget sliderControl({
      required double value,
      required double max,
      required String label,
      required ValueChanged<double> onChanged,
      required ValueChanged<double> onChangeEnd,
    }) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Slider(
              value: value,
              max: max,
              divisions: 20,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: GoogleFonts.geistMono(fontSize: 12.5, color: _textPrimary),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          title: appStrings.settingsPersona,
          children: <Widget>[
            _SettingsBlock(
              anchor: 'persona',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    appStrings.personaBehaviorNotes,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appStrings.durableInstructionsForVoiceAndInteraction,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AutosaveTextField(
                    value: controller.memoryOverview.assistantBehaviorNotes,
                    minLines: 4,
                    maxLines: 10,
                    onSave: (text) => unawaited(
                      controller.updateAssistantBehaviorNotes(text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.socialIntelligence2,
          description: appStrings.oneRuntimeControlsPersonaGroupTurn,
          children: <Widget>[
            _SettingsRow(
              anchor: 'socialBehavior',
              label: appStrings.enableBehaviorModules,
              description:
                  appStrings.directMessagesRemainResponsiveAllowlistedGroups,
              control: Switch(
                value: enabled,
                onChanged: (value) =>
                    _update(<String, dynamic>{'enabled': value}),
              ),
            ),
            moduleRow(
              'socialMemory',
              appStrings.channelScopedSocialMemory,
              'social_memory',
            ),
            moduleRow('roomNorms', appStrings.learnRoomNorms, 'norms'),
            moduleRow(
              'observability',
              appStrings.socialObservability,
              'social_observability',
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.settingsFineTuning,
          description: appStrings.settingsFineTuningDescription,
          trailing: TextButton(
            onPressed: () => setState(() => _showFineTuning = !_showFineTuning),
            child: Text(
              _showFineTuning
                  ? appStrings.settingsHide
                  : appStrings.settingsShow,
            ),
          ),
          children: !_showFineTuning
              ? const <Widget>[]
              : <Widget>[
                  _SettingsRow(
                    anchor: 'turnTaking',
                    label: appStrings.turnTakingModel,
                    description:
                        controller.systemOneAvailable &&
                            controller.systemOneModel != 'off'
                        ? appStrings.systemOneDecidesWhenToSpeakWhileIt
                        : appStrings.automaticSelectsAFastModelThrough,
                    enabled: enabled,
                    fillControl: true,
                    control: _ModelPickerButton(
                      value: decisionModel,
                      options: <_ModelPickerOption>[
                        _ModelPickerOption(
                          value: '',
                          label: appStrings.automaticFast,
                          icon: Icons.auto_awesome_outlined,
                          isAuto: true,
                        ),
                        ..._modelPickerOptions(routingModels),
                      ],
                      dialogTitle: appStrings.selectArg1(
                        appStrings.turnTakingModel,
                      ),
                      onChanged: (next) {
                        if (next == null) return;
                        _update(<String, dynamic>{
                          'decisionModelId': next.isEmpty ? null : next,
                        });
                      },
                    ),
                  ),
                  _SettingsRow(
                    anchor: 'minimumNeed',
                    label: appStrings.settingsMinimumContribution,
                    description:
                        appStrings.higherValuesMakeNeoagentMoreSelective,
                    enabled: enabled,
                    fillControl: true,
                    control: sliderControl(
                      value: needScore,
                      max: 1,
                      label: needScore.toStringAsFixed(2),
                      onChanged: (value) =>
                          setState(() => _draftNeedScore = value),
                      onChangeEnd: (value) {
                        _update(<String, dynamic>{'minimumNeedScore': value});
                        setState(() => _draftNeedScore = null);
                      },
                    ),
                  ),
                  _SettingsRow(
                    anchor: 'batchWindow',
                    label: appStrings.settingsBatchWindow,
                    description: appStrings.settingsBatchWindowDescription,
                    enabled: enabled,
                    fillControl: true,
                    control: sliderControl(
                      value: batchWindow,
                      max: 5000,
                      label: appStrings.arg1Ms(batchWindow.round()),
                      onChanged: (value) =>
                          setState(() => _draftBatchWindow = value),
                      onChangeEnd: (value) {
                        _update(<String, dynamic>{
                          'batchWindowMs': value.round(),
                        });
                        setState(() => _draftBatchWindow = null);
                      },
                    ),
                  ),
                ],
        ),
      ],
    );
  }
}

/// Settings › Voice: live calls, dictation and spoken replies.
class _VoiceSettingsPage extends StatelessWidget {
  const _VoiceSettingsPage({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
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
      controller.voiceLiveProvider.isEmpty
          ? defaultProviderId
          : controller.voiceLiveProvider,
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

    final transcriptionProviders = _jsonList(
      _jsonMap(capabilities['transcription'])['providers'],
    ).whereType<Map>().toList();
    String sttDefaultModel(String id) {
      for (final provider in transcriptionProviders) {
        if (provider['id']?.toString() == id) {
          return provider['defaultModel']?.toString() ?? '';
        }
      }
      return '';
    }

    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final handsFree = controller.voiceInputMode != 'ptt';

    _SettingsRow pickerRow({
      required String anchor,
      required String label,
      String? description,
      required String value,
      required List<_ModelPickerOption> options,
      required ValueChanged<String> onChanged,
    }) {
      return _SettingsRow(
        anchor: anchor,
        label: label,
        description: description,
        fillControl: true,
        control: _ModelPickerButton(
          value: value,
          options: options,
          dialogTitle: appStrings.selectArg1(label),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          title: appStrings.liveVoice,
          description: appStrings.voiceCallsRunOnALive,
          children: <Widget>[
            _SettingsRow(
              anchor: 'inputMode',
              label: appStrings.inputMode,
              description: handsFree
                  ? appStrings.settingsHandsFreeDescription
                  : appStrings.settingsPushToTalkDescription,
              control: _SettingsChoice<String>(
                value: handsFree ? 'hands_free' : 'ptt',
                options: <(String, String)>[
                  ('hands_free', appStrings.settingsHandsFree),
                  ('ptt', appStrings.pushToTalk),
                ],
                onChanged: (value) => _autosaveSettings(
                  controller,
                  <String, dynamic>{'voice_input_mode': value},
                ),
              ),
            ),
            pickerRow(
              anchor: 'liveProvider',
              label: appStrings.liveModelProvider,
              description: appStrings.gptLiveUsesYourOpenaiApi,
              value: controller.voiceLiveProvider,
              options: <_ModelPickerOption>[
                _ModelPickerOption(
                  value: '',
                  label: appStrings.serverDefaultArg1(
                    serverDefault['label'] ?? defaultProviderId,
                  ),
                ),
                for (final provider in liveProviders)
                  _ModelPickerOption(
                    value: provider['id']?.toString() ?? '',
                    label: provider['label']?.toString() ?? '',
                  ),
              ],
              // A model or voice only fits the provider it came from.
              onChanged: (value) =>
                  _autosaveSettings(controller, <String, dynamic>{
                    'voice_live_provider': value,
                    'voice_live_model': '',
                    'voice_live_voice': '',
                  }),
            ),
            pickerRow(
              anchor: 'liveModel',
              label: appStrings.liveModel,
              value: controller.voiceLiveModel,
              options: withDefault(
                appStrings.defaultArg1(
                  effective['defaultModel'] ?? 'provider default',
                ),
                _jsonStringList(effective['models']),
                controller.voiceLiveModel,
              ),
              onChanged: (value) => _autosaveSettings(
                controller,
                <String, dynamic>{'voice_live_model': value},
              ),
            ),
            pickerRow(
              anchor: 'liveVoice',
              label: appStrings.settingsLiveVoice,
              value: controller.voiceLiveVoice,
              options: withDefault(
                appStrings.defaultArg1(
                  effective['defaultVoice'] ?? 'provider default',
                ),
                _jsonStringList(effective['voices']),
                controller.voiceLiveVoice,
              ),
              onChanged: (value) => _autosaveSettings(
                controller,
                <String, dynamic>{'voice_live_voice': value},
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.voiceNotesAndDictation,
          description: appStrings.speechToTextTranscribesVoiceNotes,
          children: <Widget>[
            pickerRow(
              anchor: 'speechToText',
              label: appStrings.speechToText,
              value: controller.voiceSttProvider,
              options: <_ModelPickerOption>[
                _ModelPickerOption(
                  value: 'auto',
                  label: appStrings.autoFirstProviderWithAnApi,
                ),
                for (final provider in transcriptionProviders)
                  _ModelPickerOption(
                    value: provider['id']?.toString() ?? '',
                    label: provider['id']?.toString() ?? '',
                  ),
              ],
              onChanged: (value) =>
                  _autosaveSettings(controller, <String, dynamic>{
                    'voice_stt_provider': value,
                    'voice_stt_model': value == 'auto'
                        ? ''
                        : sttDefaultModel(value),
                  }),
            ),
            pickerRow(
              anchor: 'voiceReplyModel',
              label: appStrings.voiceReplyModel,
              value: _ensureModelValue(
                controller.defaultSpeechModel,
                routingModels,
                allowAuto: true,
                preserveUnknown: true,
              ),
              options: _modelPickerOptions(routingModels, allowAuto: true),
              onChanged: (value) => _autosaveSettings(
                controller,
                <String, dynamic>{'default_speech_model': value},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Settings › Messaging, above the channel list: how the agent behaves in
/// group chats on every channel.
class _GroupChatDefaults extends StatelessWidget {
  const _GroupChatDefaults({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final behavior = controller.behaviorConfig;
    final enabled = behavior['enabled'] != false;
    final participation =
        const <String>{
          'automatic',
          'mention_only',
          'always',
        }.contains(behavior['participationMode']?.toString())
        ? behavior['participationMode'].toString()
        : 'automatic';
    final delivery = behavior['deliveryStyle'] == 'single'
        ? 'single'
        : 'natural_bubbles';
    return _SettingsGroup(
      title: appStrings.settingsGroupChats,
      description: enabled
          ? appStrings.settingsGroupChatsDescription
          : appStrings.settingsGroupChatsDisabled,
      children: <Widget>[
        _SettingsRow(
          anchor: 'participation',
          label: appStrings.defaultGroupParticipation,
          description: switch (participation) {
            'mention_only' =>
              appStrings.settingsParticipationMentionOnlyDescription,
            'always' => appStrings.settingsParticipationAlwaysDescription,
            _ => appStrings.settingsParticipationAutomaticDescription,
          },
          enabled: enabled,
          control: _SettingsChoice<String>(
            value: participation,
            options: <(String, String)>[
              ('automatic', appStrings.settingsParticipationAutomatic),
              ('mention_only', appStrings.settingsParticipationMentionOnly),
              ('always', appStrings.always),
            ],
            onChanged: (value) => unawaited(
              controller.updateBehaviorConfig(<String, dynamic>{
                'participationMode': value,
              }),
            ),
          ),
        ),
        _SettingsRow(
          anchor: 'delivery',
          label: appStrings.messagingDelivery,
          description: delivery == 'single'
              ? appStrings.settingsDeliverySingleDescription
              : appStrings.settingsDeliveryNaturalDescription,
          enabled: enabled,
          control: _SettingsChoice<String>(
            value: delivery,
            options: <(String, String)>[
              ('natural_bubbles', appStrings.naturalBubbles),
              ('single', appStrings.singleMessage),
            ],
            onChanged: (value) => unawaited(
              controller.updateBehaviorConfig(<String, dynamic>{
                'deliveryStyle': value,
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Settings › Computer & web: the computer the agents work on, and the sites
/// they can read with this computer's cookies.
class _ComputerSettingsPage extends StatefulWidget {
  const _ComputerSettingsPage({required this.controller});

  final NeoAgentController controller;

  @override
  State<_ComputerSettingsPage> createState() => _ComputerSettingsPageState();
}

class _ComputerSettingsPageState extends State<_ComputerSettingsPage> {
  bool _shellTestRunning = false;
  Map<String, dynamic>? _shellTestResult;
  bool _socialReachRefreshing = false;
  String? _socialReachBusyPlatform;
  Map<String, dynamic>? _socialReachActionResult;

  NeoAgentController get _controller => widget.controller;

  Future<void> _testShell() async {
    setState(() {
      _shellTestRunning = true;
      _shellTestResult = null;
    });
    try {
      final result = await _controller.testCliRuntime();
      if (mounted) setState(() => _shellTestResult = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _shellTestResult = <String, dynamic>{
            'passed': false,
            'detail': error.toString(),
          };
        });
      }
    } finally {
      if (mounted) setState(() => _shellTestRunning = false);
    }
  }

  Future<void> _refreshSocialReach() async {
    setState(() {
      _socialReachRefreshing = true;
      _socialReachActionResult = null;
    });
    try {
      await _controller.refreshSocialReachStatus();
    } catch (error) {
      if (mounted) {
        setState(
          () => _socialReachActionResult = <String, dynamic>{
            'error': error.toString(),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _socialReachRefreshing = false);
    }
  }

  Future<void> _runSocialReachAction(
    String platform,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() {
      _socialReachBusyPlatform = platform;
      _socialReachActionResult = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => _socialReachActionResult = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _socialReachActionResult = <String, dynamic>{
            'error': error.toString(),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _socialReachBusyPlatform = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final state = controller.computerRuntime['state']?.toString() ?? 'stopped';
    final running = const <String>{
      'ready',
      'user_control',
      'agent_control',
      'teaching',
    }.contains(state);
    final shellResult = _shellTestResult;
    final shellPassed = shellResult?['passed'] == true;
    final shellDetail = shellResult?['detail']?.toString() ?? '';
    final platforms = _jsonList(
      controller.socialReachStatus['platforms'],
    ).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    final actionResult = _socialReachActionResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          title: appStrings.computerWorkspace,
          description: appStrings.browserLinuxDesktopFilesTerminalAnd,
          children: <Widget>[
            _SettingsRow(
              anchor: 'computerRuntime',
              label: appStrings.settingsComputerStatus,
              description: appStrings.theRuntimeIsALightweightDebian,
              control: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _DotStatus(
                    label: state.replaceAll('_', ' '),
                    color: running
                        ? _success
                        : state == 'error'
                        ? _danger
                        : _warning,
                  ),
                  if (running)
                    OutlinedButton(
                      onPressed: controller.isRunningDeviceAction
                          ? null
                          : controller.stopComputerRuntime,
                      child: Text(appStrings.stop),
                    )
                  else
                    FilledButton(
                      onPressed: controller.isRunningDeviceAction
                          ? null
                          : controller.startComputerRuntime,
                      child: Text(appStrings.openComputer),
                    ),
                ],
              ),
            ),
            _SettingsRow(
              anchor: 'shell',
              label: appStrings.computerShell,
              description: shellResult == null
                  ? appStrings.commandsRunInTheSamePersistent
                  : shellPassed
                  ? (shellDetail.isNotEmpty
                        ? shellDetail
                        : appStrings.arg1Ok(appStrings.computerShell))
                  : shellDetail,
              control: OutlinedButton(
                onPressed: _shellTestRunning ? null : _testShell,
                child: _shellTestRunning
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(appStrings.settingsTest),
              ),
            ),
          ],
        ),
        _SettingsGroup(
          anchor: 'socialReach',
          title: appStrings.socialReach2,
          description: appStrings.socialSourcesAgentsCanReadDirectly,
          trailing: IconButton(
            tooltip: appStrings.refresh,
            onPressed: _socialReachRefreshing ? null : _refreshSocialReach,
            icon: _socialReachRefreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh_rounded),
          ),
          children: <Widget>[
            if (actionResult != null)
              _SettingsBlock(
                child: actionResult['error'] == null
                    ? _InlineSuccess(message: appStrings.socialReachUpdated)
                    : _InlineError(message: actionResult['error'].toString()),
              ),
            if (platforms.isEmpty)
              _SettingsBlock(
                child: Text(
                  appStrings.statusIsNotLoadedYet,
                  style: TextStyle(color: _textSecondary),
                ),
              )
            else
              for (final platform in platforms) _socialReachRow(platform),
          ],
        ),
      ],
    );
  }

  Widget _socialReachRow(Map<String, dynamic> platform) {
    final id = platform['platform']?.toString() ?? '';
    final status = platform['status']?.toString().toLowerCase() ?? 'off';
    final message = platform['message']?.toString() ?? '';
    final cookie = _jsonMap(platform['cookie']);
    final busy = _socialReachBusyPlatform == id;
    final ready = platform['ready'] == true || status == 'ok';
    final cookieLine = cookie.isEmpty
        ? ''
        : cookie['configured'] == true
        ? appStrings.arg1CookiesImported(cookie['count'] ?? 0)
        : appStrings.cookiesNotConfigured;
    return _SettingsRow(
      label: platform['label']?.toString() ?? id,
      description: <String>[
        message,
        cookieLine,
      ].where((line) => line.isNotEmpty).join('\n'),
      control: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _StatusPill(
            label: status,
            color: ready
                ? _success
                : status == 'warn'
                ? _warning
                : status == 'error'
                ? _danger
                : _textSecondary,
          ),
          if (platform['setupKind'] == 'cookies') ...<Widget>[
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _runSocialReachAction(
                      id,
                      () => _controller.importSocialReachCookies(id),
                    ),
              child: Text(appStrings.importFromComputer),
            ),
            IconButton(
              tooltip: appStrings.clear,
              onPressed: busy
                  ? null
                  : () => _runSocialReachAction(
                      id,
                      () => _controller.clearSocialReachCookies(id),
                    ),
              icon: Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings › General: appearance, language, time and this app's own
/// behavior.
class _GeneralSettingsPage extends StatefulWidget {
  const _GeneralSettingsPage({required this.controller});

  final NeoAgentController controller;

  @override
  State<_GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<_GeneralSettingsPage> {
  List<String> _zones = const <String>[];
  String? _deviceZone;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final deviceZone = await _controller.deviceTimeZone();
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

  void _setFollowsDevice(bool follow) {
    final deviceZone = _deviceZone;
    _autosaveSettings(_controller, <String, dynamic>{
      'timezone_auto': follow,
      if (follow && deviceZone != null) 'timezone': deviceZone,
    });
  }

  void _chooseZone(String zone) {
    if (zone == _controller.timeZone) return;
    _autosaveSettings(_controller, <String, dynamic>{
      'timezone_auto': false,
      'timezone': zone,
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final followsDevice = controller.timeZoneFollowsDevice;
    final currentZone = controller.timeZone;
    final closeChoice = controller.desktopAskOnClose
        ? 'ask'
        : controller.desktopKeepRunningOnClose
        ? 'keep'
        : 'quit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsGroup(
          title: appStrings.settingsAppearance,
          children: <Widget>[
            _SettingsRow(
              anchor: 'theme',
              label: appStrings.settingsTheme,
              tag: appStrings.thisDevice,
              control: _SettingsChoice<ThemeMode>(
                value: controller.themeMode,
                options: <(ThemeMode, String)>[
                  (ThemeMode.system, appStrings.settingsThemeSystem),
                  (ThemeMode.light, appStrings.settingsThemeLight),
                  (ThemeMode.dark, appStrings.settingsThemeDark),
                ],
                onChanged: (mode) => unawaited(controller.setThemeMode(mode)),
              ),
            ),
            _SettingsRow(
              anchor: 'language',
              label: appStrings.accountLanguageTitle,
              description: appStrings.accountLanguageDescription,
              control: _SettingsChoice<AppLanguage>(
                value: controller.language,
                options: <(AppLanguage, String)>[
                  for (final language in AppLanguage.values)
                    (language, language.label),
                ],
                onChanged: (language) =>
                    unawaited(controller.setLanguage(language)),
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: appStrings.timeZone2,
          description: appStrings.theAgentReadsTimesYouMention,
          children: <Widget>[
            _SettingsRow(
              anchor: 'followDeviceZone',
              label: appStrings.matchThisDevice,
              description: _deviceZone == null
                  ? appStrings.updateTheTimeZoneAutomaticallyFrom
                  : appStrings.thisDeviceArg1(_deviceZone),
              control: Switch(
                value: followsDevice,
                onChanged: _setFollowsDevice,
              ),
            ),
            _SettingsRow(
              anchor: 'timeZone',
              label: appStrings.timeZone2,
              description: currentZone.isEmpty ? appStrings.notSet : null,
              enabled: !followsDevice,
              fillControl: true,
              control: _zones.isEmpty
                  ? Text(currentZone, style: TextStyle(color: _textPrimary))
                  : DropdownMenu<String>(
                      key: ValueKey<String>('timezone-$currentZone'),
                      initialSelection: _zones.contains(currentZone)
                          ? currentZone
                          : null,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      menuHeight: 320,
                      leadingIcon: Icon(Icons.search, size: 18),
                      dropdownMenuEntries: _zones
                          .map(
                            (zone) => DropdownMenuEntry<String>(
                              value: zone,
                              label: zone,
                            ),
                          )
                          .toList(),
                      onSelected: (zone) {
                        if (zone != null) _chooseZone(zone);
                      },
                    ),
            ),
          ],
        ),
        if (_supportsDesktopShell)
          _SettingsGroup(
            title: appStrings.desktopApp,
            children: <Widget>[
              _SettingsRow(
                anchor: 'closeWindow',
                label: appStrings.settingsCloseWindow,
                tag: appStrings.thisDevice,
                description: switch (closeChoice) {
                  'keep' => appStrings.settingsCloseKeepRunningDescription,
                  'quit' => appStrings.settingsCloseQuitDescription,
                  _ => appStrings.promptBeforeNeoagentStaysResidentIn,
                },
                control: _SettingsChoice<String>(
                  value: closeChoice,
                  options: <(String, String)>[
                    ('ask', appStrings.settingsCloseAsk),
                    ('keep', appStrings.keepRunning),
                    ('quit', appStrings.quit),
                  ],
                  onChanged: (choice) => unawaited(
                    controller.setDesktopClosePreference(
                      askOnClose: choice == 'ask',
                      keepRunningOnClose: choice == 'ask'
                          ? controller.desktopKeepRunningOnClose
                          : choice == 'keep',
                    ),
                  ),
                ),
              ),
              _SettingsRow(
                anchor: 'hotkey',
                label: appStrings.reserveAssistantHotkey,
                tag: appStrings.thisDevice,
                description: appStrings.registerArg1ForTheAssistantSummon(
                  _desktopAssistantHotkeyLabel,
                ),
                control: Switch(
                  value: controller.desktopAssistantHotkeyEnabled,
                  onChanged: controller.setDesktopAssistantHotkeyEnabled,
                ),
              ),
            ],
          ),
        if (_isMobileDevice())
          _SettingsGroup(
            title: appStrings.settingsPhoneTriggers,
            description: appStrings.settingsPhoneTriggersDescription,
            children: <Widget>[
              _SettingsRow(
                anchor: 'locationTriggers',
                label: appStrings.settingsLocationTriggers,
                tag: appStrings.thisDevice,
                description: appStrings.settingsLocationTriggersDescription,
                control: Switch(
                  value: controller.locationTriggersEnabled,
                  onChanged: controller.setLocationTriggersEnabled,
                ),
              ),
              if (Platform.isAndroid)
                _SettingsRow(
                  anchor: 'notificationTriggers',
                  label: appStrings.settingsNotificationTriggers,
                  tag: appStrings.thisDevice,
                  description:
                      appStrings.settingsNotificationTriggersDescription,
                  control: Switch(
                    value: controller.notificationTriggersEnabled,
                    onChanged: controller.setNotificationTriggersEnabled,
                  ),
                ),
            ],
          ),
        _SettingsGroup(
          title: appStrings.settingsSetup,
          children: <Widget>[
            _SettingsRow(
              anchor: 'onboarding',
              label: appStrings.settingsOnboarding,
              description: appStrings.settingsOnboardingDescription,
              control: OutlinedButton.icon(
                onPressed: controller.reopenOnboarding,
                icon: Icon(Icons.replay_rounded, size: 16),
                label: Text(appStrings.redoOnboarding),
              ),
            ),
          ],
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
            dialogTitle: appStrings.selectArg1(label),
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
