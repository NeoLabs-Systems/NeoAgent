part of 'main.dart';

class VoiceAssistantPanel extends StatefulWidget {
  const VoiceAssistantPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  late final AudioPlayer _assistantPlayer;
  Timer? _elapsedTimer;
  bool _elapsedTickerActive = false;
  bool _pttPressed = false;
  bool _isAssistantPlaying = false;
  bool _isMuted = false;
  String? _voiceError;
  String? _assistantAudioMimeType;
  String? _lastLiveError;
  final List<Uint8List> _audioQueue = <Uint8List>[];
  bool _isDraining = false;
  bool _audioInterrupted = false;
  int _audioQueueConsumedCount = 0;

  String _liveStateLabel(VoiceAssistantLiveState state) {
    switch (state.state.trim().toLowerCase()) {
      case 'listening':
        return 'Listening';
      case 'transcribing':
        return 'Transcribing';
      case 'triaging':
        return 'Triaging';
      case 'working':
        return 'Working';
      case 'waiting':
        return 'Waiting';
      case 'blocked':
        return 'Blocked';
      case 'speaking':
        return 'Speaking';
      case 'interrupted':
        return 'Interrupted';
      case 'reconnecting':
        return 'Reconnecting';
      case 'connected':
        return 'Connected';
      case 'error':
        return 'Error';
      default:
        return 'Ready';
    }
  }

  String _heroHintForState(
    VoiceAssistantLiveState liveState,
    bool liveCaptureStarting,
    bool liveCaptureEngaged,
    bool useDesktopToggleCapture,
  ) {
    if (liveCaptureEngaged) {
      return useDesktopToggleCapture
          ? 'Tap again to finish.'
          : 'Release to finish.';
    }
    if (liveCaptureStarting) {
      return 'Starting voice capture...';
    }
    switch (liveState.state.trim().toLowerCase()) {
      case 'transcribing':
        return 'Transcribing your speech...';
      case 'triaging':
        return 'Choosing the quickest safe path...';
      case 'working':
        return 'NeoAgent is working on your request...';
      case 'waiting':
        return 'Waiting for the current operation...';
      case 'blocked':
        return 'NeoAgent needs approval or input to continue.';
      case 'speaking':
        return 'Playing the reply...';
      case 'reconnecting':
        return 'Reconnecting without stopping the task...';
      case 'interrupted':
        return 'Reply interrupted.';
      case 'error':
        return 'Voice capture hit an error.';
      default:
        return useDesktopToggleCapture ? 'Tap to talk.' : 'Hold to talk.';
    }
  }

  @override
  void initState() {
    super.initState();
    _assistantPlayer = AudioPlayer();
    _applyAndroidCallAudioContext();
    widget.controller.addListener(_handleControllerChanged);
    _assistantPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAssistantPlaying = false;
      });
    });
    _syncElapsedTicker();
  }

  /// Android routes voice sessions through a self-managed Telecom connection, which
  /// puts the device in communication mode. Replies played with the default media
  /// usage are ducked or sent to the earpiece there, so the assistant sounds silent.
  void _applyAndroidCallAudioContext() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    unawaited(
      _assistantPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.inCommunication,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _elapsedTimer?.cancel();
    unawaited(_assistantPlayer.dispose());
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _syncElapsedTicker();
    _syncLiveVoiceState();
    setState(() {});
  }

  void _syncElapsedTicker() {
    final shouldRun =
        widget.controller.isLiveVoiceCaptureActive ||
        widget.controller.isLiveVoiceCaptureStarting;
    if (shouldRun == _elapsedTickerActive) {
      return;
    }

    _elapsedTickerActive = shouldRun;
    _elapsedTimer?.cancel();
    if (!shouldRun) {
      return;
    }

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _syncLiveVoiceState() {
    final liveState = widget.controller.voiceAssistantLiveState;
    _assistantAudioMimeType = liveState.audioMimeType;
    _voiceError = liveState.error;

    final currentError = liveState.error?.trim();
    if ((currentError?.isNotEmpty ?? false) && currentError != _lastLiveError) {
      _lastLiveError = currentError;
      _audioInterrupted = true;
      _audioQueue.clear();
      _audioQueueConsumedCount = 0;
      unawaited(_stopAssistantAudio());
    } else if (currentError == null || currentError.isEmpty) {
      _lastLiveError = null;
    }

    // If the state queue was cleared (e.g. on interrupt), reset cursor.
    final incoming = liveState.audioQueue;
    if (_audioQueueConsumedCount > incoming.length) {
      _audioQueueConsumedCount = 0;
    }

    // Only enqueue chunks we haven't seen yet.
    if (incoming.length > _audioQueueConsumedCount) {
      _audioInterrupted = false;
      final newChunks = incoming.sublist(_audioQueueConsumedCount);
      _audioQueueConsumedCount = incoming.length;
      for (final chunk in newChunks) {
        if (chunk.isNotEmpty) _audioQueue.add(chunk);
      }
      unawaited(_drainAudioQueue());
    }
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
    unawaited(_startPttCapture());
  }

  void _handlePrimaryPointerUp(PointerEvent event) {
    if (!_hasActivePttCapture() && !_pttPressed) {
      return;
    }
    unawaited(_stopPttCapture());
  }

  Future<void> _startPttCapture() async {
    AppDiagnostics.log(
      'voice.assistant.ui',
      'capture_start.request',
      data: <String, Object?>{
        'hasActiveSession':
            widget.controller.voiceAssistantLiveState.hasActiveSession,
      },
    );
    setState(() {
      _pttPressed = true;
      _voiceError = null;
    });

    try {
      await widget.controller.startLiveVoiceCapture();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceError = widget.controller._friendlyErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _pttPressed = false;
        });
      }
    }
  }

  Future<void> _stopPttCapture() async {
    AppDiagnostics.log('voice.assistant.ui', 'capture_stop.request');
    await widget.controller.stopLiveVoiceCapture();
  }

  Future<void> _drainAudioQueue() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      while (_audioQueue.isNotEmpty && !_audioInterrupted) {
        final chunk = _audioQueue.removeAt(0);
        if (chunk.isEmpty) continue;
        final mimeType = (_assistantAudioMimeType?.trim().isNotEmpty ?? false)
            ? _assistantAudioMimeType!.trim()
            : null;
        // Wait for the previous clip to finish before starting the next.
        final completer = Completer<void>();
        late StreamSubscription<void> sub;
        sub = _assistantPlayer.onPlayerComplete.listen((_) {
          sub.cancel();
          completer.complete();
        });
        await _assistantPlayer.setVolume(_isMuted ? 0 : 1);
        await _assistantPlayer.play(BytesSource(chunk, mimeType: mimeType));
        if (!mounted || _audioInterrupted) {
          sub.cancel();
          break;
        }
        if (mounted) setState(() => _isAssistantPlaying = true);
        await completer.future;
        if (mounted) {
          setState(() => _isAssistantPlaying = _audioQueue.isNotEmpty);
        }
      }
    } finally {
      _isDraining = false;
      if (mounted && !_isAssistantPlaying) {
        setState(() => _isAssistantPlaying = false);
      }
    }
  }

  Future<void> _stopAssistantAudio() async {
    _audioInterrupted = true;
    _audioQueue.clear();
    await _assistantPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = false;
    });
  }

  String _activeCallElapsedLabel(NeoAgentController controller) {
    final startedAt = controller.liveVoiceCaptureStartedAt;
    if (startedAt == null) {
      return '00:00';
    }
    final elapsed = DateTime.now().difference(startedAt);
    final totalSeconds = math.max(0, elapsed.inSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    final muted = !_isMuted;
    await _assistantPlayer.setVolume(muted ? 0 : 1);
    if (!mounted) return;
    setState(() => _isMuted = muted);
  }

  Future<void> _stopSpeaking(NeoAgentController controller) async {
    await _stopAssistantAudio();
    await controller.stopLiveVoicePlayback();
  }

  Future<void> _endSession(NeoAgentController controller) async {
    final hasActiveTask = controller.voiceAssistantLiveState.activeRunId
        .trim()
        .isNotEmpty;
    if (!hasActiveTask) {
      await controller.closeLiveVoiceSession();
      return;
    }
    final cancelTask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End voice session?'),
        content: const Text(
          'NeoAgent is still working. You can end the voice session and keep the chat task running, or cancel the task too.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue session'),
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

  String _timelineKindLabel(VoiceTimelineItem item) {
    switch (item.kind) {
      case 'acknowledgement':
        return 'Acknowledgement';
      case 'progress':
        return 'Progress';
      case 'status':
        return 'Status';
      case 'error':
        return 'Error';
      case 'transcript_partial':
        return 'Listening';
      default:
        return item.role == 'user' ? 'You' : 'NeoAgent';
    }
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
          'Transcripts, grounded progress, and NeoAgent replies appear here in order.',
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
                        _timelineKindLabel(item),
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

  Widget _buildLiveSessionCard(NeoAgentController controller) {
    final liveState = controller.voiceAssistantLiveState;
    final statusLabel = controller.isLiveVoiceCaptureStarting
        ? 'Starting'
        : liveState.hasActiveSession
        ? liveState.state.isNotEmpty
              ? liveState.state
              : 'Ready'
        : liveState.isRecoverable
        ? 'Reconnecting'
        : 'Idle';
    final helperText = liveState.hasActiveSession
        ? '${liveState.mediaMode.toUpperCase()} • ${liveState.provider.toUpperCase()} • ${liveState.model}'
        : liveState.isRecoverable
        ? 'Reconnecting the live turn.'
        : 'Open a push-to-talk session to start.';
    return _VoiceAssistantSectionCard(
      icon: Icons.graphic_eq_outlined,
      title: 'Live Session',
      subtitle: helperText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _StatusPill(
                label: statusLabel,
                color: controller.isLiveVoiceCaptureStarting
                    ? _warning
                    : liveState.isBusy
                    ? _accent
                    : _success,
              ),
              _StatusPill(
                label: _activeCallElapsedLabel(controller),
                color: controller.isLiveVoiceCaptureActive ? _warning : _accent,
              ),
              if (liveState.hasActiveSession)
                _StatusPill(
                  label: liveState.transportState,
                  color: _textSecondary,
                ),
            ],
          ),
          if (liveState.hasActiveSession) ...<Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _StatusPill(
                  label: liveState.provider.toUpperCase(),
                  color: _accent,
                ),
                _StatusPill(label: liveState.model, color: _textSecondary),
                _StatusPill(
                  label: liveState.inputMode == 'hands_free'
                      ? 'HANDS-FREE'
                      : 'PUSH-TO-TALK',
                  color: _textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.voiceAssistantLiveState.hasActiveSession
                    ? () => _stopSpeaking(controller)
                    : controller.ensureLiveVoiceSession,
                icon: Icon(
                  controller.voiceAssistantLiveState.hasActiveSession
                      ? Icons.stop_circle_outlined
                      : Icons.power_settings_new_outlined,
                  size: 18,
                ),
                label: Text(
                  controller.voiceAssistantLiveState.hasActiveSession
                      ? 'Stop speaking'
                      : 'Open live session',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    controller.voiceAssistantLiveState.activeRunId
                        .trim()
                        .isNotEmpty
                    ? controller.cancelLiveVoiceTask
                    : null,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel task'),
              ),
              OutlinedButton.icon(
                onPressed: controller.voiceAssistantLiveState.hasActiveSession
                    ? () => _endSession(controller)
                    : null,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('End session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final liveState = controller.voiceAssistantLiveState;
    final liveCaptureStarting = controller.isLiveVoiceCaptureStarting;
    final viewportSize = MediaQuery.sizeOf(context);
    final heroHeight = math
        .min(760, math.max(360, viewportSize.height * 0.72))
        .toDouble();
    final assistantUi = _DesktopAssistantControlState.fromController(
      controller,
    );
    final globalError = controller.errorMessage?.trim();
    final voiceError = _voiceError?.trim();
    final liveCaptureEngaged = assistantUi.isCapturing;
    final isBusy = _pttPressed || liveCaptureEngaged;
    final canStart = !isBusy;
    final canStop = liveCaptureEngaged;
    final hasAssistantAudio = _isAssistantPlaying || _audioQueue.isNotEmpty;
    final useDesktopToggleCapture =
        liveState.inputMode == 'hands_free' || assistantUi.useToggleCapture;
    final heroHint = _heroHintForState(
      liveState,
      liveCaptureStarting,
      liveCaptureEngaged,
      useDesktopToggleCapture,
    );
    final heroButton = useDesktopToggleCapture
        ? _VoiceAssistantHeroButton(
            icon: liveCaptureEngaged ? Icons.stop_rounded : Icons.mic,
            color: (liveCaptureEngaged || _pttPressed)
                ? _warning
                : assistantUi.primaryColor,
            active: liveCaptureEngaged || _pttPressed,
            onTap: canStart || canStop
                ? controller.toggleLiveVoiceCapture
                : null,
          )
        : Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: canStart ? _handlePrimaryPointerDown : null,
            onPointerUp: (canStop || canStart) ? _handlePrimaryPointerUp : null,
            onPointerCancel: (canStop || canStart)
                ? _handlePrimaryPointerUp
                : null,
            child: _VoiceAssistantHeroButton(
              icon: liveCaptureEngaged ? Icons.hearing : Icons.mic,
              color: (liveCaptureEngaged || _pttPressed)
                  ? _warning
                  : assistantUi.primaryColor,
              active: liveCaptureEngaged || _pttPressed,
              onTap: null,
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
                                label: _liveStateLabel(liveState),
                                color: liveState.isBusy ? _danger : _success,
                              ),
                              _StatusPill(
                                label: _activeCallElapsedLabel(controller),
                                color: liveCaptureEngaged ? _warning : _accent,
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
                                heroHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (liveCaptureStarting) ...<Widget>[
                                const SizedBox(height: 10),
                                Text(
                                  'The app is preparing the microphone and session.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if ((globalError?.isNotEmpty ?? false) &&
                                  globalError != voiceError) ...<Widget>[
                                const SizedBox(height: 16),
                                _InlineError(message: globalError!),
                              ],
                              if (voiceError?.isNotEmpty ?? false) ...<Widget>[
                                const SizedBox(height: 10),
                                _InlineError(message: voiceError!),
                              ],
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            liveState.state.trim().toLowerCase() == 'idle'
                                ? 'Transcript and reply update below.'
                                : '${_liveStateLabel(liveState)} in progress.',
                            style: TextStyle(color: _textMuted, height: 1.4),
                          ),
                        ),
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
                      icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: liveState.hasActiveSession ? _toggleMute : null,
                    ),
                    _VoiceAssistantActionButton(
                      icon: Icons.stop_circle_outlined,
                      label: 'Stop speaking',
                      onTap: hasAssistantAudio
                          ? () => _stopSpeaking(controller)
                          : null,
                    ),
                    _VoiceAssistantActionButton(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      onTap: controller.ensureLiveVoiceSession,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLiveSessionCard(controller),
                const SizedBox(height: 18),
                _VoiceAssistantSectionCard(
                  icon: Icons.forum_outlined,
                  title: 'Conversation',
                  subtitle:
                      'One ordered timeline shared with the NeoAgent chat task.',
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
  });

  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: active ? 1.03 : 1,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
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
