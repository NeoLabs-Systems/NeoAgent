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
  String _assistantReply = '';
  String _assistantTranscript = '';
  String? _voiceError;
  Uint8List? _assistantAudioBytes;
  String? _assistantAudioMimeType;
  String _lastLiveAudioFingerprint = '';
  String? _lastLiveError;

  @override
  void initState() {
    super.initState();
    _assistantPlayer = AudioPlayer();
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

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _elapsedTimer?.cancel();
    unawaited(_assistantPlayer.dispose());
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncElapsedTicker();
    _syncLiveVoiceState();
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
    _assistantReply = liveState.assistantText;
    _assistantTranscript = liveState.finalTranscript.ifEmpty(
      liveState.partialTranscript,
    );
    _assistantAudioBytes = liveState.audioBytes;
    _assistantAudioMimeType = liveState.audioMimeType;
    _voiceError = liveState.error;

    final currentError = liveState.error?.trim();
    if ((currentError?.isNotEmpty ?? false) && currentError != _lastLiveError) {
      _lastLiveError = currentError;
      unawaited(_stopAssistantAudio());
    } else if (currentError == null || currentError.isEmpty) {
      _lastLiveError = null;
    }

    final bytes = liveState.audioBytes;
    final fingerprint = bytes.isEmpty
        ? ''
        : '${bytes.length}:${bytes.take(8).join(',')}';
    if (fingerprint.isEmpty) {
      _lastLiveAudioFingerprint = '';
    }
    if (fingerprint.isNotEmpty && fingerprint != _lastLiveAudioFingerprint) {
      _lastLiveAudioFingerprint = fingerprint;
      unawaited(_playAssistantAudio());
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

  Future<void> _playAssistantAudio() async {
    final bytes = _assistantAudioBytes;
    if (bytes == null || bytes.isEmpty) {
      return;
    }

    await _assistantPlayer.stop();
    final mimeType = (_assistantAudioMimeType?.trim().isNotEmpty ?? false)
        ? _assistantAudioMimeType!.trim()
        : null;
    await _assistantPlayer.play(BytesSource(bytes, mimeType: mimeType));
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = true;
    });
  }

  Future<void> _stopAssistantAudio() async {
    await _assistantPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = false;
    });
  }

  String _activeCallElapsedLabel(RecordingRuntimeStatus runtime) {
    final startedAt = runtime.startedAt;
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

  Widget _buildLiveSessionCard(NeoAgentController controller) {
    final liveState = controller.voiceAssistantLiveState;
    final preview = liveState.finalTranscript.ifEmpty(
      liveState.partialTranscript,
    );
    final helperText = liveState.hasActiveSession
        ? '${liveState.provider.toUpperCase()} • ${liveState.model} • ${liveState.state}'
        : 'Open a push-to-talk session to start live voice.';
    return _VoiceAssistantSectionCard(
      icon: Icons.graphic_eq_outlined,
      title: 'Live Session',
      subtitle: helperText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            preview.trim().isEmpty
                ? 'Partial and final transcript text will appear here while the turn is in progress.'
                : preview,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: preview.trim().isEmpty ? _textMuted : _textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.voiceAssistantLiveState.hasActiveSession
                    ? controller.interruptLiveVoiceAssistant
                    : controller.ensureLiveVoiceSession,
                icon: Icon(
                  controller.voiceAssistantLiveState.hasActiveSession
                      ? Icons.stop_circle_outlined
                      : Icons.power_settings_new_outlined,
                  size: 18,
                ),
                label: Text(
                  controller.voiceAssistantLiveState.hasActiveSession
                      ? 'Interrupt output'
                      : 'Open live session',
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.voiceAssistantLiveState.hasActiveSession
                    ? controller.closeLiveVoiceSession
                    : null,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close session'),
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
    final runtime = controller.recordingRuntime;
    final liveState = controller.voiceAssistantLiveState;
    final liveCaptureEngaged =
        controller.isLiveVoiceCaptureActive ||
        controller.isLiveVoiceCaptureStarting;
    final isBusy = _pttPressed || liveCaptureEngaged;
    final canStart = !isBusy;
    final canStop = liveCaptureEngaged;
    final hasAssistantAudio =
        _assistantAudioBytes != null && _assistantAudioBytes!.isNotEmpty;
    final captureLabel = liveCaptureEngaged
        ? _activeCallElapsedLabel(runtime)
        : 'Ready';
    final useDesktopToggleCapture = _desktopAssistantUsesToggleControls();

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Voice Assistant',
          subtitle:
              'Push to talk, optionally steer the reply, and play back the response.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _DotStatus(
                label: liveState.state.isEmpty ? 'Standby' : liveState.state,
                color: liveState.isBusy ? _danger : _success,
              ),
              _StatusPill(
                label:
                    '${controller.voiceLiveProvider.toUpperCase()} · ${controller.voiceLiveVoice}',
                color: _accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
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
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      _accent.withValues(alpha: 0.96),
                                      _accentHover,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  liveCaptureEngaged
                                      ? Icons.hearing
                                      : Icons.support_agent,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Neo Assistant',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    liveCaptureEngaged
                                        ? 'Listening live'
                                        : 'Ready for next turn',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    liveState.hasActiveSession
                                        ? (useDesktopToggleCapture
                                              ? 'Tap again to commit audio and let NeoAgent respond with live voice updates.'
                                              : 'Release the mic to commit audio and let NeoAgent respond with live voice updates.')
                                        : (useDesktopToggleCapture
                                              ? 'Tap to start speaking. The live session stays separate from the recording workflow.'
                                              : 'Hold to talk. The live session stays separate from the recording workflow.'),
                                    style: TextStyle(
                                      color: _textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              _VoiceAssistantMetricChip(
                                label: 'Elapsed',
                                value: captureLabel,
                              ),
                              _VoiceAssistantMetricChip(
                                label: 'Source',
                                value: 'Direct mic',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          useDesktopToggleCapture
                              ? _VoiceAssistantPrimaryAction(
                                  icon: liveCaptureEngaged
                                      ? Icons.stop_rounded
                                      : Icons.mic,
                                  label: _desktopAssistantPrimaryLabel(
                                    liveCaptureEngaged,
                                  ),
                                  caption: _desktopAssistantPrimaryCaption(
                                    liveCaptureEngaged,
                                  ),
                                  color: (liveCaptureEngaged || _pttPressed)
                                      ? _warning
                                      : _success,
                                  onTap: liveCaptureEngaged
                                      ? _stopPttCapture
                                      : (canStart ? _startPttCapture : null),
                                )
                              : Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: canStart
                                      ? _handlePrimaryPointerDown
                                      : null,
                                  onPointerUp: (canStop || canStart)
                                      ? _handlePrimaryPointerUp
                                      : null,
                                  onPointerCancel: (canStop || canStart)
                                      ? _handlePrimaryPointerUp
                                      : null,
                                  child: _VoiceAssistantPrimaryAction(
                                    icon: liveCaptureEngaged
                                        ? Icons.mic_off
                                        : Icons.mic,
                                    label: _desktopAssistantPrimaryLabel(
                                      liveCaptureEngaged,
                                    ),
                                    caption: _desktopAssistantPrimaryCaption(
                                      liveCaptureEngaged,
                                    ),
                                    color: (liveCaptureEngaged || _pttPressed)
                                        ? _warning
                                        : _success,
                                    onTap: null,
                                  ),
                                ),
                          const SizedBox(width: 22),
                          _VoiceAssistantPrimaryAction(
                            icon: Icons.call_end,
                            label: 'End turn',
                            caption: 'Commit the active live capture',
                            color: _danger,
                            onTap: canStop ? _stopPttCapture : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          _VoiceAssistantActionButton(
                            icon: _isAssistantPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.play_arrow,
                            label: _isAssistantPlaying
                                ? 'Stop playback'
                                : 'Play reply',
                            onTap: hasAssistantAudio
                                ? (_isAssistantPlaying
                                      ? _stopAssistantAudio
                                      : _playAssistantAudio)
                                : null,
                          ),
                          _VoiceAssistantActionButton(
                            icon: Icons.refresh,
                            label: 'Refresh',
                            onTap: controller.ensureLiveVoiceSession,
                          ),
                        ],
                      ),
                      if (controller.errorMessage?.trim().isNotEmpty ??
                          false) ...<Widget>[
                        const SizedBox(height: 14),
                        _InlineError(message: controller.errorMessage!),
                      ],
                      if (_voiceError?.trim().isNotEmpty ?? false) ...<Widget>[
                        const SizedBox(height: 10),
                        _InlineError(message: _voiceError!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final cards = <Widget>[
                      Expanded(child: _buildLiveSessionCard(controller)),
                      Expanded(
                        child: _VoiceAssistantSectionCard(
                          icon: Icons.record_voice_over_outlined,
                          title: 'Assistant Reply',
                          subtitle: hasAssistantAudio
                              ? 'Audio reply ready for playback.'
                              : 'Text reply and speech status.',
                          child: Text(
                            _assistantReply.trim().isEmpty
                                ? 'No assistant reply yet.'
                                : _assistantReply,
                            style: TextStyle(
                              color: _assistantReply.trim().isEmpty
                                  ? _textMuted
                                  : _textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ];
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          cards.first,
                          const SizedBox(width: 18),
                          cards.last,
                        ],
                      );
                    }
                    return Column(
                      children: <Widget>[
                        cards.first,
                        const SizedBox(height: 18),
                        cards.last,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _VoiceAssistantSectionCard(
                  icon: Icons.subject_outlined,
                  title: 'Transcript',
                  subtitle:
                      'Partial and final transcript text for the live turn.',
                  child: Text(
                    _assistantTranscript.trim().isEmpty
                        ? 'Transcript will appear while or after you finish the live turn.'
                        : _assistantTranscript,
                    style: TextStyle(
                      color: _assistantTranscript.trim().isEmpty
                          ? _textMuted
                          : _textPrimary,
                      height: 1.5,
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

class _VoiceAssistantPrimaryAction extends StatelessWidget {
  const _VoiceAssistantPrimaryAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 94,
                height: 94,
                child: Icon(icon, size: 38, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}

class _VoiceAssistantMetricChip extends StatelessWidget {
  const _VoiceAssistantMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bgCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
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
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
