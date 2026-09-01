part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cowork — composer
//
// The composer owns everything about *how* the next message runs: Agent/Plan
// mode and the model. Context about *where* it runs (agent, device, folder)
// lives in the thread header.
// ─────────────────────────────────────────────────────────────────────────────

class _CoworkComposer extends StatelessWidget {
  const _CoworkComposer({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onDictate,
    required this.onSend,
    required this.isDictating,
    required this.isTranscribing,
    required this.compact,
  });

  final NeoAgentController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final List<SharedChatAttachment> attachments;
  final ValueChanged<SharedChatAttachment> onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onDictate;
  final VoidCallback onSend;
  final bool isDictating;
  final bool isTranscribing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chat = controller.selectedCoworkChat;
    final thread = controller.selectedCoworkThread;
    final enabled =
        chat != null && controller.socketConnected && !thread.loading;
    final steering = thread.hasLiveRun;
    final plan = chat?.mode == CoworkInteractionMode.plan;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 6, compact ? 10 : 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (attachments.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: attachments
                  .map(
                    (attachment) => InputChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 17),
                      label: Text(attachment.name),
                      onDeleted: () => onRemoveAttachment(attachment),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: steering
                    ? _accentAlt.withValues(alpha: 0.5)
                    : _borderLight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                        enabled ? onSend : () {},
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      control: true,
                    ): enabled
                        ? onSend
                        : () {},
                  },
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 9,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: chat == null
                          ? 'Start a session to begin'
                          : steering
                          ? 'Steer the active run…'
                          : plan
                          ? 'Describe what to plan…'
                          : 'Describe what to build or change…',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (chat != null) ...<Widget>[
                      _CoworkModeSwitch(
                        chat: chat,
                        enabled: !steering,
                        onChanged: (mode) => controller.updateCoworkChat(
                          chat.id,
                          <String, dynamic>{'mode': mode},
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CoworkModelPill(controller: controller, chat: chat),
                    ],
                    const Spacer(),
                    _ChatComposerIconButton(
                      tooltip: 'Attach files',
                      icon: Icons.attach_file_rounded,
                      onPressed: enabled ? onAttach : null,
                    ),
                    const SizedBox(width: 4),
                    isTranscribing
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _ChatComposerIconButton(
                            tooltip: isDictating
                                ? 'Stop dictation'
                                : 'Dictate',
                            icon: isDictating
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_rounded,
                            color: isDictating
                                ? Theme.of(context).colorScheme.error
                                : null,
                            onPressed: enabled && !isTranscribing
                                ? onDictate
                                : null,
                          ),
                    const SizedBox(width: 6),
                    _ChatComposerIconButton(
                      tooltip: steering ? 'Steer run (⌘↵)' : 'Send (⌘↵)',
                      icon: steering
                          ? Icons.alt_route_rounded
                          : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      backgroundColor: enabled ? _accent : _textMuted,
                      onPressed: enabled ? onSend : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            steering
                ? 'Messages steer the current run · ⌘↵ send · ⌘. stop'
                : plan
                ? 'Plan mode inspects only; nothing is changed until you implement · ⌘↵ send'
                : 'Agent mode edits the workspace · ⌘↵ send · ⌘N new session',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.geistMono(fontSize: 10.5, color: _textMuted),
          ),
        ],
      ),
    );
  }
}

class _CoworkModeSwitch extends StatelessWidget {
  const _CoworkModeSwitch({
    required this.chat,
    required this.enabled,
    required this.onChanged,
  });

  final CoworkChat chat;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final plan = chat.mode == CoworkInteractionMode.plan;
    return Tooltip(
      message: enabled
          ? 'Agent edits the workspace. Plan only inspects.'
          : 'Mode locks while a run is active.',
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _bgSecondary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: _borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _CoworkSegPill(
                dense: true,
                selected: !plan,
                icon: Icons.bolt_rounded,
                label: 'Agent',
                onTap: () {
                  if (enabled && plan) onChanged('agent');
                },
              ),
              _CoworkSegPill(
                dense: true,
                selected: plan,
                icon: Icons.route_outlined,
                label: 'Plan',
                onTap: () {
                  if (enabled && !plan) onChanged('plan');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact per-session model override. "Default" follows the chat model in
/// Settings; anything else is sent as the run's model.
class _CoworkModelPill extends StatelessWidget {
  const _CoworkModelPill({required this.controller, required this.chat});

  final NeoAgentController controller;
  final CoworkChat chat;

  @override
  Widget build(BuildContext context) {
    final value = chat.modelOverride ?? 'default';
    final options = _taskModelOverrideOptions(
      selectedModel: value,
      models: controller.supportedModels,
    );
    final current = options.firstWhere(
      (option) => option.value == value,
      orElse: () => _ModelPickerOption(value: value, label: value),
    );
    final label = current.value == 'default' ? 'Default model' : current.label;
    return _CoworkContextPill(
      icon: current.isAuto
          ? Icons.auto_awesome_outlined
          : current.icon ?? Icons.memory_rounded,
      label: label,
      accent: current.value != 'default',
      maxWidth: 160,
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (dialogContext) => _ModelPickerDialog(
          title: 'Model for this session',
          options: options,
          currentValue: value,
          onChanged: (selected) {
            Navigator.of(dialogContext).pop();
            unawaited(
              controller.updateCoworkChat(chat.id, <String, dynamic>{
                'modelOverride': selected == 'default' ? null : selected,
              }),
            );
          },
        ),
      ),
    );
  }
}
