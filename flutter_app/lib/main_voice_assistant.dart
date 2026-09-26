part of 'main.dart';

class VoiceAssistantPanel extends StatefulWidget {
  const VoiceAssistantPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  Timer? _elapsedTimer;
  bool _elapsedTickerActive = false;
  bool _pttPressed = false;

  String _liveStateLabel(
    NeoAgentController controller,
    VoiceAssistantLiveState state,
  ) {
    if (!state.hasActiveSession) {
      return state.isConnecting ? 'Connecting' : 'Ready';
    }
    if (state.transportState != 'connected') return 'Reconnecting';
    switch (state.state) {
      case 'connecting':
        return 'Connecting';
      case 'reconnecting':
        return 'Reconnecting';
      case 'speaking':
        return 'Speaking';
      default:
        if (state.isHandsFree && !controller.isLiveVoiceCaptureActive) {
          return 'Muted';
        }
        return 'Listening';
    }
  }

  String _heroHint(
    NeoAgentController controller,
    VoiceAssistantLiveState state,
    bool useToggleCapture,
  ) {
    if (controller.isLiveVoiceCaptureStarting || state.isConnecting) {
      return 'Connecting to the live voice model...';
    }
    if (!state.hasActiveSession) {
      return useToggleCapture ? 'Tap to start talking.' : 'Hold to talk.';
    }
    if (state.isHandsFree) {
      return controller.isLiveVoiceCaptureActive
          ? 'Just talk. You can interrupt at any time. Tap to mute.'
          : 'Microphone muted. Tap to unmute.';
    }
    return controller.isLiveVoiceCaptureActive
        ? (useToggleCapture
              ? 'Tap again when you are done.'
              : 'Release when you are done.')
        : (useToggleCapture ? 'Tap to talk.' : 'Hold to talk.');
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _syncElapsedTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _syncElapsedTicker();
    setState(() {});
  }

  void _syncElapsedTicker() {
    final shouldRun =
        widget.controller.voiceAssistantLiveState.hasActiveSession;
    if (shouldRun == _elapsedTickerActive) {
      return;
    }
    _elapsedTickerActive = shouldRun;
    _elapsedTimer?.cancel();
    if (!shouldRun) {
      return;
    }
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  bool _hasActivePttCapture() {
    final controller = widget.controller;
    return controller.isLiveVoiceCaptureActive ||
        controller.isLiveVoiceCaptureStarting;
  }

  void _handlePrimaryPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    if (_hasActivePttCapture()) {
      return;
    }
    unawaited(_startCapture());
  }

  void _handlePrimaryPointerUp(PointerEvent event) {
    if (!_hasActivePttCapture() && !_pttPressed) {
      return;
    }
    unawaited(widget.controller.stopLiveVoiceCapture());
  }

  Future<void> _startCapture() async {
    AppDiagnostics.log(
      'voice.assistant.ui',
      'capture_start.request',
      data: <String, Object?>{
        'hasActiveSession':
            widget.controller.voiceAssistantLiveState.hasActiveSession,
      },
    );
    setState(() => _pttPressed = true);
    try {
      await widget.controller.startLiveVoiceCapture();
    } catch (_) {
      // The controller records the error on the live state.
    } finally {
      if (mounted) setState(() => _pttPressed = false);
    }
  }

  Future<void> _toggleCapture() async {
    try {
      await widget.controller.toggleLiveVoiceCapture();
    } catch (_) {
      // The controller records the error on the live state.
    }
  }

  String _callElapsedLabel(NeoAgentController controller) {
    final startedAt = controller.liveVoiceSessionStartedAt;
    if (startedAt == null) {
      return '00:00';
    }
    final totalSeconds = math.max(
      0,
      DateTime.now().difference(startedAt).inSeconds,
    );
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  Future<void> _endSession(NeoAgentController controller) async {
    if (!controller.voiceAssistantLiveState.hasActiveTask) {
      await controller.closeLiveVoiceSession();
      return;
    }
    final cancelTask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End voice call?'),
        content: const Text(
          'NeoAgent is still working on a task. End the call and get the result in chat, or cancel the task too.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay on the call'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep task running'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel task'),
          ),
        ],
      ),
    );
    if (cancelTask == null || !mounted) return;
    await controller.closeLiveVoiceSession(cancelTask: cancelTask);
  }

  Widget _buildTimeline(VoiceAssistantLiveState liveState) {
    if (liveState.timeline.isEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Text(
          'What you and NeoAgent say appears here and in the chat.',
          style: TextStyle(color: _textMuted, height: 1.45),
        ),
      );
    }
    return Column(
      children: liveState.timeline
          .map((item) {
            final assistant = item.role == 'assistant';
            return Container(
              key: ValueKey<String>(item.id),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: assistant
                    ? _accent.withValues(alpha: 0.08)
                    : _bgSecondary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: assistant ? _accentMuted : _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        assistant
                            ? Icons.auto_awesome_outlined
                            : Icons.person_outline,
                        size: 16,
                        color: assistant ? _accent : _textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        assistant ? 'NeoAgent' : 'You',
                        style: TextStyle(
                          color: assistant ? _accent : _textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!item.isFinal) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          'Live',
                          style: TextStyle(color: _textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    item.content,
                    style: TextStyle(color: _textPrimary, height: 1.45),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildTaskBanner(NeoAgentController controller) {
    final liveState = controller.voiceAssistantLiveState;
    final request = liveState.activeTaskRequest.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentMuted),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.isEmpty
                  ? 'Working on a task in the background.'
                  : 'Working in the background: $request',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textPrimary, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: controller.cancelLiveVoiceTask,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(VoiceAssistantLiveState liveState) {
    return _VoiceAssistantSectionCard(
      icon: Icons.graphic_eq_outlined,
      title: 'Live model',
      subtitle: liveState.hasActiveSession
          ? 'Speech-to-speech with the same memory, tools and chat history as NeoAgent.'
          : 'Choose the live model and voice in Settings.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          if (liveState.provider.isNotEmpty)
            _StatusPill(
              label: liveState.provider.toUpperCase(),
              color: _accent,
            ),
          if (liveState.model.isNotEmpty)
            _StatusPill(label: liveState.model, color: _textSecondary),
          if (liveState.voice.isNotEmpty)
            _StatusPill(label: liveState.voice, color: _textSecondary),
          _StatusPill(
            label: liveState.isHandsFree ? 'HANDS-FREE' : 'PUSH-TO-TALK',
            color: _textSecondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final liveState = controller.voiceAssistantLiveState;
    final viewportSize = MediaQuery.sizeOf(context);
    final heroHeight = math
        .min(760, math.max(360, viewportSize.height * 0.72))
        .toDouble();
    final assistantUi = _DesktopAssistantControlState.fromController(
      controller,
    );
    final globalError = controller.errorMessage?.trim();
    final voiceError = liveState.error?.trim();
    final captureEngaged = assistantUi.isCapturing;
    final useToggleCapture =
        liveState.isHandsFree || assistantUi.useToggleCapture;
    final heroActive = captureEngaged || _pttPressed;
    final heroColor = heroActive ? _warning : assistantUi.primaryColor;
    final heroButton = useToggleCapture
        ? _VoiceAssistantHeroButton(
            icon: heroActive ? Icons.mic : Icons.mic_off_outlined,
            color: heroColor,
            active: heroActive,
            onTap: _toggleCapture,
          )
        : Semantics(
            button: true,
            label: captureEngaged ? 'Release to finish' : 'Hold to talk',
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePrimaryPointerDown,
              onPointerUp: _handlePrimaryPointerUp,
              onPointerCancel: _handlePrimaryPointerUp,
              child: _VoiceAssistantHeroButton(
                icon: captureEngaged ? Icons.hearing : Icons.mic,
                color: heroColor,
                active: heroActive,
                enabled: true,
                onTap: null,
              ),
            ),
          );

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: heroHeight,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          _bgSecondary.withValues(alpha: 0.98),
                          _bgPrimary.withValues(alpha: 0.96),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _borderLight),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 26,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topCenter,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: <Widget>[
                              _DotStatus(
                                label: _liveStateLabel(controller, liveState),
                                color: liveState.isSpeaking
                                    ? _accent
                                    : liveState.hasActiveSession
                                    ? _success
                                    : _textMuted,
                              ),
                              if (liveState.hasActiveSession)
                                _StatusPill(
                                  label: _callElapsedLabel(controller),
                                  color: _accent,
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              heroButton,
                              const SizedBox(height: 18),
                              Text(
                                _heroHint(
                                  controller,
                                  liveState,
                                  useToggleCapture,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((globalError?.isNotEmpty ?? false) &&
                                  globalError != voiceError) ...<Widget>[
                                const SizedBox(height: 16),
                                _InlineError(
                                  message: globalError!,
                                  onDismiss: controller.clearInlineError,
                                ),
                              ],
                              if (voiceError?.isNotEmpty ?? false) ...<Widget>[
                                const SizedBox(height: 10),
                                _InlineError(message: voiceError!),
                              ],
                            ],
                          ),
                        ),
                        if (liveState.hasActiveTask)
                          _buildTaskBanner(controller),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    _VoiceAssistantActionButton(
                      icon: Icons.stop_circle_outlined,
                      label: 'Stop speaking',
                      onTap: liveState.isSpeaking
                          ? controller.stopLiveVoicePlayback
                          : null,
                    ),
                    _VoiceAssistantActionButton(
                      icon: Icons.call_end,
                      label: 'End call',
                      onTap: liveState.hasActiveSession
                          ? () => _endSession(controller)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSessionCard(liveState),
                const SizedBox(height: 18),
                _VoiceAssistantSectionCard(
                  icon: Icons.forum_outlined,
                  title: 'Conversation',
                  subtitle: 'Shared with the NeoAgent chat and its memory.',
                  child: _buildTimeline(liveState),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceAssistantSectionCard extends StatelessWidget {
  const _VoiceAssistantSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderLight),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: _textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _VoiceAssistantActionButton extends StatelessWidget {
  const _VoiceAssistantActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 128),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: _textPrimary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceAssistantHeroButton extends StatelessWidget {
  const _VoiceAssistantHeroButton({
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
    this.enabled,
  });

  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onTap;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled ?? onTap != null;
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: active ? 1.03 : 1,
      child: Opacity(
        opacity: interactive ? 1 : 0.5,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          elevation: active ? 10 : 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Icon(icon, size: 56, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
