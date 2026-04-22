part of 'main.dart';

class VoiceAssistantPanel extends StatefulWidget {
  const VoiceAssistantPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  late final AudioPlayer _assistantPlayer;
  late final AudioPlayer _thinkingPlayer;
  Timer? _elapsedTimer;
  bool _elapsedTickerActive = false;
  bool _pttPressed = false;
  bool _isAssistantPlaying = false;
  bool _isThinkingAudioPlaying = false;
  String _assistantReply = '';
  String _assistantTranscript = '';
  String? _voiceError;
  String? _assistantAudioMimeType;
  String? _lastLiveError;
  final List<Uint8List> _audioQueue = <Uint8List>[];
  late final Uint8List _thinkingAudioLoopBytes;
  bool _isDraining = false;
  bool _audioInterrupted = false;
  int _audioQueueConsumedCount = 0;

  @override
  void initState() {
    super.initState();
    _assistantPlayer = AudioPlayer();
    _thinkingPlayer = AudioPlayer();
    _thinkingAudioLoopBytes = _buildThinkingLoopWav();
    widget.controller.addListener(_handleControllerChanged);
    _assistantPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAssistantPlaying = false;
      });
      unawaited(_syncThinkingAudio());
    });
    _syncElapsedTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _elapsedTimer?.cancel();
    unawaited(_assistantPlayer.dispose());
    unawaited(_thinkingPlayer.dispose());
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncElapsedTicker();
    _syncLiveVoiceState();
    unawaited(_syncThinkingAudio());
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
    _assistantReply = liveState.finalAssistantText.ifEmpty(
      liveState.interimAssistantText,
    );
    _assistantTranscript = liveState.finalTranscript.ifEmpty(
      liveState.partialTranscript,
    );
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

  Future<void> _syncThinkingAudio() async {
    final state = widget.controller.voiceAssistantLiveState.state.trim();
    final shouldPlay = state == 'thinking' && !_isAssistantPlaying;
    if (shouldPlay == _isThinkingAudioPlaying) {
      return;
    }
    if (shouldPlay) {
      try {
        await _thinkingPlayer.setReleaseMode(ReleaseMode.loop);
        await _thinkingPlayer.setVolume(0.08);
        await _thinkingPlayer.play(
          BytesSource(_thinkingAudioLoopBytes, mimeType: 'audio/wav'),
        );
        _isThinkingAudioPlaying = true;
      } catch (error, stackTrace) {
        AppDiagnostics.log(
          'voice.assistant.ui',
          'thinking_audio.start_failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }
    await _stopThinkingAudio();
  }

  Future<void> _stopThinkingAudio() async {
    if (!_isThinkingAudioPlaying) {
      return;
    }
    await _thinkingPlayer.stop();
    _isThinkingAudioPlaying = false;
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
        await _stopThinkingAudio();
        await _assistantPlayer.play(BytesSource(chunk, mimeType: mimeType));
        if (!mounted || _audioInterrupted) {
          sub.cancel();
          break;
        }
        if (mounted) setState(() => _isAssistantPlaying = true);
        await completer.future;
        if (mounted)
          setState(() => _isAssistantPlaying = _audioQueue.isNotEmpty);
      }
    } finally {
      _isDraining = false;
      if (mounted && !_isAssistantPlaying)
        setState(() => _isAssistantPlaying = false);
    }
  }

  Future<void> _playAssistantAudio() async {
    // Legacy path — not used for live streaming but kept for any non-streaming callers.
    _audioInterrupted = false;
    unawaited(_drainAudioQueue());
  }

  Future<void> _stopAssistantAudio() async {
    _audioInterrupted = true;
    _audioQueue.clear();
    await _stopThinkingAudio();
    await _assistantPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAssistantPlaying = false;
    });
  }

  Uint8List _buildThinkingLoopWav() {
    const sampleRate = 24000;
    const durationMs = 2400;
    const channelCount = 1;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * durationMs) ~/ 1000;
    final dataLength = sampleCount * 2;
    final bytes = ByteData(44 + dataLength);

    void writeString(int offset, String value) {
      for (var i = 0; i < value.length; i += 1) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channelCount, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channelCount * (bitsPerSample ~/ 8),
      Endian.little,
    );
    bytes.setUint16(32, channelCount * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeString(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    final twoPi = math.pi * 2;
    for (var i = 0; i < sampleCount; i += 1) {
      final time = i / sampleRate;
      final progress = i / sampleCount;
      final eased = math.sin(progress * math.pi);
      final pad =
          math.sin(twoPi * 196 * time) * 0.35 +
          math.sin(twoPi * 246.94 * time) * 0.2 +
          math.sin(twoPi * 293.66 * time) * 0.12;
      final shimmer =
          math.sin(twoPi * 523.25 * time + math.sin(twoPi * 0.23 * time)) *
          0.05;
      final tremolo = 0.58 + 0.42 * math.sin(twoPi * 0.45 * time);
      final envelope = math.pow(eased, 1.6).toDouble() * tremolo;
      final sample = ((pad + shimmer) * envelope * 1400).round().clamp(
        -32768,
        32767,
      );
      bytes.setInt16(44 + (i * 2), sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
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

  Widget _buildLiveSessionCard(NeoAgentController controller) {
    final liveState = controller.voiceAssistantLiveState;
    final preview = liveState.finalTranscript.ifEmpty(
      liveState.partialTranscript,
    );
    final helperText = liveState.hasActiveSession
        ? '${liveState.provider.toUpperCase()} • ${liveState.model} • ${liveState.state} • ${liveState.transportState}'
        : liveState.isRecoverable
        ? 'Reconnecting live voice turn...'
        : 'Open a push-to-talk session to start live voice.';
    return _VoiceAssistantSectionCard(
      icon: Icons.graphic_eq_outlined,
      title: 'Live Session',
      subtitle: helperText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              ],
            ),
            const SizedBox(height: 14),
          ],
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
    final liveState = controller.voiceAssistantLiveState;
    final viewportSize = MediaQuery.sizeOf(context);
    final heroHeight = math
        .min(760, math.max(360, viewportSize.height * 0.72))
        .toDouble();
    final assistantUi = _DesktopAssistantControlState.fromController(
      controller,
      blockedHintVisible: false,
    );
    final liveCaptureEngaged = assistantUi.isCapturing;
    final isBusy = _pttPressed || liveCaptureEngaged;
    final canStart = !isBusy;
    final canStop = liveCaptureEngaged;
    final hasAssistantAudio = _isAssistantPlaying || _audioQueue.isNotEmpty;
    final useDesktopToggleCapture = assistantUi.useToggleCapture;
    final heroHint = liveCaptureEngaged
        ? (useDesktopToggleCapture
              ? 'Tap again to finish.'
              : 'Release to finish.')
        : (useDesktopToggleCapture ? 'Tap to talk.' : 'Hold to talk.');
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
                                label: liveState.state.isEmpty
                                    ? 'Standby'
                                    : liveState.state,
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
                              if (controller.errorMessage?.trim().isNotEmpty ??
                                  false) ...<Widget>[
                                const SizedBox(height: 16),
                                _InlineError(message: controller.errorMessage!),
                              ],
                              if (_voiceError?.trim().isNotEmpty ??
                                  false) ...<Widget>[
                                const SizedBox(height: 10),
                                _InlineError(message: _voiceError!),
                              ],
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            'Scroll for details',
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
                    _VoiceAssistantScreenContextButton(
                      controller: controller,
                      compact: false,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 820;
                    final liveSessionCard = _buildLiveSessionCard(controller);
                    final assistantReplyCard = _VoiceAssistantSectionCard(
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
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: liveSessionCard),
                          const SizedBox(width: 18),
                          Expanded(child: assistantReplyCard),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        liveSessionCard,
                        const SizedBox(height: 18),
                        assistantReplyCard,
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
