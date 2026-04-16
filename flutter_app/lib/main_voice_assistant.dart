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
  bool _isRunningAssistant = false;
  bool _isAssistantPlaying = false;
  String _assistantReply = '';
  String _assistantTranscript = '';
  String? _voiceError;
  Uint8List? _assistantAudioBytes;
  String? _assistantAudioMimeType;
  String? _lastCapturedSessionId;

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
  }

  void _syncElapsedTicker() {
    final shouldRun = widget.controller.recordingRuntime.active;
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

  Future<void> _startPttCapture() async {
    final runtime = widget.controller.recordingRuntime;
    if (runtime.active || widget.controller.isStartingRecording) {
      return;
    }

    setState(() {
      _pttPressed = true;
      _voiceError = null;
    });

    try {
      if (kIsWeb) {
        await widget.controller.startWebMicrophoneRecording();
      } else if (runtime.supportsBackgroundMic) {
        await widget.controller.startBackgroundRecording();
      } else if (runtime.supportsScreenAndMic) {
        await widget.controller.startWebRecording();
      }
      _lastCapturedSessionId = widget.controller.recordingRuntime.sessionId;
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
    final runtime = widget.controller.recordingRuntime;
    if (!runtime.active || widget.controller.isStoppingRecording) {
      return;
    }

    final capturedSessionId = runtime.sessionId;
    await widget.controller.stopRecording(stopReason: 'voice_assistant');

    final targetSessionId = capturedSessionId ?? _lastCapturedSessionId;
    if (targetSessionId != null && targetSessionId.trim().isNotEmpty) {
      await _runAssistantTurn(targetSessionId.trim());
    }
  }

  Future<void> _runAssistantTurn(String sessionId) async {
    if (_isRunningAssistant) {
      return;
    }

    setState(() {
      _isRunningAssistant = true;
      _voiceError = null;
    });

    try {
      final result = await widget.controller.runVoiceAssistantTurn(
        sessionId: sessionId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _assistantReply = result.replyText;
        _assistantTranscript = result.transcript;
        _assistantAudioBytes = result.audioBytes;
        _assistantAudioMimeType = result.audioMimeType;
        _voiceError = null;
        if ((_assistantAudioBytes?.isEmpty ?? true) &&
            (result.ttsError?.trim().isNotEmpty ?? false)) {
          _voiceError =
              'Speech playback unavailable (${result.ttsProvider ?? 'tts'}): ${result.ttsError}';
        }
      });

      if (_assistantAudioBytes != null && _assistantAudioBytes!.isNotEmpty) {
        await _playAssistantAudio();
      }
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
          _isRunningAssistant = false;
        });
      }
    }
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

  RecordingSessionItem? _latestVoiceSession() {
    for (final session in widget.controller.recordingSessions) {
      final hasAudioSource = session.sources.any(
        (source) => source.mediaKind == 'audio' && source.chunkCount > 0,
      );
      if (hasAudioSource) {
        return session;
      }
    }
    return null;
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

  String _captureStateLabel(RecordingRuntimeStatus runtime) {
    if (runtime.active) {
      return runtime.paused ? 'Capture paused' : 'Listening live';
    }
    return 'Ready for next turn';
  }

  String _captureStateSubtitle(
    RecordingRuntimeStatus runtime,
    RecordingSessionItem? latestSession,
  ) {
    if (runtime.active) {
      return 'Release the mic to transcribe and run the assistant.';
    }
    if (latestSession == null) {
      return 'Hold to talk, then NeoOS will answer in text and optional speech.';
    }
    return '${latestSession.statusLabel} • ${latestSession.startedAtLabel}';
  }

  Widget _buildLatestSessionCard(
    NeoAgentController controller,
    RecordingSessionItem? latestSession,
  ) {
    final preview = latestSession?.transcriptText.trim() ?? '';
    final helperText = latestSession == null
        ? 'No voice capture yet. Start a push-to-talk session to create one.'
        : '${latestSession.platformLabel} • ${latestSession.durationLabel} • ${latestSession.statusLabel}';
    return _VoiceAssistantSectionCard(
      icon: Icons.fiber_smart_record_outlined,
      title: 'Latest Capture',
      subtitle: helperText,
      child: latestSession == null
          ? Text(
              'Recent microphone captures will appear here so you can inspect them before rerunning the reply.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _StatusPill(
                      label: latestSession.statusLabel,
                      color: latestSession.statusColor,
                    ),
                    const SizedBox(width: 8),
                    if (latestSession.lastError?.trim().isNotEmpty ?? false)
                      Expanded(
                        child: Text(
                          latestSession.lastError!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _danger),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  preview.isEmpty ? 'Transcript not ready yet.' : preview,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: preview.isEmpty ? _textMuted : _textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: controller.refreshRecordings,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh sessions'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          latestSession.status == 'completed' &&
                              !_isRunningAssistant &&
                              !controller.recordingRuntime.active
                          ? () => _runAssistantTurn(latestSession.id)
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(
                        _isRunningAssistant ? 'Generating reply' : 'Run reply',
                      ),
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
    final hasCaptureCapability =
        kIsWeb || runtime.supportsBackgroundMic || runtime.supportsScreenAndMic;
    final isBusy =
        controller.isStartingRecording || controller.isStoppingRecording;
    final canStart = hasCaptureCapability && !isBusy && !runtime.active;
    final canStop = runtime.active && !controller.isStoppingRecording;
    final latestSession = _latestVoiceSession();
    final canGenerate =
        !_isRunningAssistant &&
        latestSession != null &&
        latestSession.status == 'completed' &&
        !runtime.active;
    final hasAssistantAudio =
        _assistantAudioBytes != null && _assistantAudioBytes!.isNotEmpty;
    final captureLabel = runtime.active
        ? _activeCallElapsedLabel(runtime)
        : latestSession?.durationLabel ?? 'Push to talk';

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
                label: runtime.active
                    ? (runtime.paused ? 'Paused' : 'Listening')
                    : 'Standby',
                color: runtime.active ? _danger : _success,
              ),
              _StatusPill(
                label:
                    '${controller.voiceTtsProvider.toUpperCase()} · ${controller.voiceTtsVoice}',
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
                                  runtime.active
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
                                    _captureStateLabel(runtime),
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _captureStateSubtitle(
                                      runtime,
                                      latestSession,
                                    ),
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
                                value: kIsWeb
                                    ? 'Web mic'
                                    : runtime.platformLabel?.ifEmpty(
                                            'Device',
                                          ) ??
                                          'Device',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          GestureDetector(
                            onLongPressStart: canStart
                                ? (_) => unawaited(_startPttCapture())
                                : null,
                            onLongPressEnd: canStop
                                ? (_) => unawaited(_stopPttCapture())
                                : null,
                            onLongPressCancel: canStop
                                ? () => unawaited(_stopPttCapture())
                                : null,
                            child: _VoiceAssistantPrimaryAction(
                              icon: runtime.active ? Icons.mic_off : Icons.mic,
                              label: runtime.active
                                  ? 'Release to send'
                                  : 'Hold to talk',
                              caption: runtime.active
                                  ? 'Stop capture and submit'
                                  : 'Press and hold for quick capture',
                              color: (runtime.active || _pttPressed)
                                  ? _warning
                                  : _success,
                              onTap: canStart ? _startPttCapture : null,
                            ),
                          ),
                          const SizedBox(width: 22),
                          _VoiceAssistantPrimaryAction(
                            icon: Icons.call_end,
                            label: 'End turn',
                            caption: 'Stop the active recording',
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
                            icon: Icons.auto_awesome_outlined,
                            label: _isRunningAssistant
                                ? 'Generating'
                                : 'Generate reply',
                            onTap: canGenerate
                                ? () => _runAssistantTurn(latestSession.id)
                                : null,
                          ),
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
                            onTap: controller.refreshRecordings,
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
                      if (!hasCaptureCapability) ...<Widget>[
                        const SizedBox(height: 10),
                        _InlineError(
                          message:
                              'This device does not expose a supported microphone capture mode.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final cards = <Widget>[
                      Expanded(
                        child: _buildLatestSessionCard(
                          controller,
                          latestSession,
                        ),
                      ),
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
                      'The exact text used for the latest assistant turn.',
                  child: Text(
                    _assistantTranscript.trim().isEmpty
                        ? 'Transcript will appear after you finish a voice turn.'
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
