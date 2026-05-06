part of 'main.dart';

class RecordingsPanel extends StatefulWidget {
  const RecordingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RecordingsPanel> createState() => _RecordingsPanelState();
}

class _RecordingsPanelState extends State<RecordingsPanel> {
  Future<void> _deleteSegment(
    BuildContext context,
    RecordingSessionItem session,
    RecordingTranscriptSegment segment,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete segment?',
      message:
          'Remove the transcript segment at ${segment.timestampLabel} from "${session.title}"?',
      onConfirm: () =>
          widget.controller.deleteRecordingSegment(session.id, segment.id),
    );
  }

  Future<void> _deleteRecording(
    BuildContext context,
    RecordingSessionItem session,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete recording?',
      message:
          'Remove the full recording "${session.title}", including audio chunks and transcript data?',
      onConfirm: () => widget.controller.deleteRecordingSession(session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.controller.recordingRuntime;
    final isStarting = widget.controller.isStartingRecording;
    final isStopping = widget.controller.isStoppingRecording;
    final statusLabel = isStarting
        ? 'Starting'
        : isStopping
        ? 'Stopping'
        : runtime.active
        ? (runtime.paused ? 'Paused' : 'Recording')
        : 'Ready';
    final statusColor = isStarting || isStopping
        ? _accent
        : runtime.active
        ? (runtime.paused ? _warning : _danger)
        : _success;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Recordings',
          subtitle:
              'Capture sessions, monitor device state, and review transcripts with clearer status and playback controls.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Capture controls',
                            style: _displayTitleStyle(24),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            runtime.platformLabel?.trim().isNotEmpty == true
                                ? runtime.platformLabel!
                                : 'Browser screen + microphone recorder',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _StatusPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isStarting
                      ? _GlassSurface(
                          key: const ValueKey<String>('starting'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          blurSigma: 10,
                          fillColor: _bgCard.withValues(alpha: 0.88),
                          borderColor: _borderLight,
                          child: Row(
                            children: <Widget>[
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Starting recording. This can take a few seconds while the session and permissions are prepared.',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : isStopping
                      ? _GlassSurface(
                          key: const ValueKey<String>('stopping'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          blurSigma: 10,
                          fillColor: _bgCard.withValues(alpha: 0.88),
                          borderColor: _borderLight,
                          child: Text(
                            'Finalizing recording...',
                            style: TextStyle(
                              color: _textSecondary,
                              height: 1.4,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (isStarting || isStopping) const SizedBox(height: 14),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    if (runtime.supportsScreenAndMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startWebRecording,
                        icon: Icon(Icons.desktop_windows_outlined),
                        label: Text('Screen + mic'),
                      ),
                    if (runtime.supportsScreenAndMic)
                      OutlinedButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startWebMicrophoneRecording,
                        icon: Icon(Icons.graphic_eq_outlined),
                        label: Text('Mic only'),
                      ),
                    if (runtime.supportsBackgroundMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startBackgroundRecording,
                        icon: Icon(Icons.mic_none_outlined),
                        label: Text('Background mic'),
                      ),
                    if (runtime.supportsSystemAudio)
                      FilledButton.icon(
                        onPressed: widget.controller.canStartDesktopRecording
                            ? widget.controller.startDesktopRecording
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentAlt,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(Icons.surround_sound_outlined),
                        label: Text('Desktop studio'),
                      ),
                    if (runtime.supportsBackgroundMic && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? widget.controller.resumeBackgroundRecording
                            : widget.controller.pauseBackgroundRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.supportsSystemAudio && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? widget.controller.resumeDesktopRecording
                            : widget.controller.pauseDesktopRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.active)
                      OutlinedButton.icon(
                        onPressed: widget.controller.isStoppingRecording
                            ? null
                            : widget.controller.stopRecording,
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('Stop'),
                      ),
                    if (runtime.supportsFloatingToolbar)
                      OutlinedButton.icon(
                        onPressed: !runtime.active
                            ? null
                            : (runtime.floatingToolbarVisible
                                  ? widget.controller.hideDesktopFloatingToolbar
                                  : widget
                                        .controller
                                        .showDesktopFloatingToolbar),
                        icon: Icon(
                          runtime.floatingToolbarVisible
                              ? Icons.visibility_off_outlined
                              : Icons.open_in_new_rounded,
                        ),
                        label: Text(
                          runtime.floatingToolbarVisible
                              ? 'Hide floating bar'
                              : 'Show floating bar',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.refreshRecordings,
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                    ),
                  ],
                ),
                if (runtime.supportsSystemAudio) ...<Widget>[
                  const SizedBox(height: 20),
                  _GlassSurface(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(22),
                    blurSigma: 10,
                    fillColor: _bgCard.withValues(alpha: 0.9),
                    borderColor: _borderLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Desktop runtime diagnostics',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Permissions and live levels stay visible while the floating bar handles quick controls.',
                          style: TextStyle(color: _textSecondary, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _RecordingPermissionBadge(
                              label: 'Microphone',
                              state: runtime.microphonePermission,
                            ),
                            _RecordingPermissionBadge(
                              label: 'System audio',
                              state: runtime.systemAudioPermission,
                            ),
                            _DotStatus(
                              label: runtime.backgroundRuntimeActive
                                  ? 'Background runtime ready'
                                  : 'Foreground only',
                              color: runtime.backgroundRuntimeActive
                                  ? _success
                                  : _warning,
                            ),
                            _DotStatus(
                              label: runtime.supportsGlobalHotkeys
                                  ? 'Hotkey-ready'
                                  : 'No global hotkeys',
                              color: runtime.supportsGlobalHotkeys
                                  ? _success
                                  : _warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: <Widget>[
                            _AudioLevelBar(
                              label: 'Microphone',
                              valueDb: runtime.microphoneLevelDb,
                              color: _accent,
                            ),
                            _AudioLevelBar(
                              label: 'System audio',
                              valueDb: runtime.systemAudioLevelDb,
                              color: _accentAlt,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            if ((runtime.selectedInputDeviceName ?? '')
                                .trim()
                                .isNotEmpty)
                              _MetaPill(
                                icon: Icons.mic_external_on_outlined,
                                label:
                                    'Input ${runtime.selectedInputDeviceName!}',
                              ),
                            _MetaPill(
                              icon: Icons.tune_outlined,
                              label:
                                  '${runtime.availableInputDevices.length} input device${runtime.availableInputDevices.length == 1 ? '' : 's'}',
                            ),
                            if (runtime.activeSources.isNotEmpty)
                              _MetaPill(
                                icon: Icons.multitrack_audio_outlined,
                                label: runtime.activeSources.join(' + '),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: widget
                                  .controller
                                  .openDesktopMicrophoneSettings,
                              icon: Icon(Icons.settings_voice_outlined),
                              label: Text('Mic settings'),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget
                                  .controller
                                  .openDesktopSystemAudioSettings,
                              icon: Icon(Icons.speaker_group_outlined),
                              label: Text('System audio settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (runtime.errorMessage != null &&
                    runtime.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _InlineError(message: runtime.errorMessage!),
                ],
              ],
            ),
          ),
        ),
        const _SectionTitle('Transcripts'),
        const SizedBox(height: 12),
        if (widget.controller.recordingSessions.isEmpty)
          const _EmptyCard(
            title: 'No recordings yet',
            subtitle: 'Start one and transcripts will appear here.',
          )
        else
          ...widget.controller.recordingSessions.map(
            (session) => Padding(
              key: ValueKey<String>(session.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordingSessionCard(
                controller: widget.controller,
                session: session,
                onRetry:
                    (session.status == 'failed' ||
                        (session.status == 'completed' &&
                            session.transcriptText.trim().isEmpty &&
                            session.transcriptSegments.isEmpty &&
                            session.structuredContent.isEmpty))
                    ? () => widget.controller.retryRecording(session.id)
                    : null,
                onDeleteSegment: (segment) =>
                    _deleteSegment(context, session, segment),
                onDeleteRecording: () => _deleteRecording(context, session),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingSessionCard extends StatelessWidget {
  const _RecordingSessionCard({
    required this.controller,
    required this.session,
    this.onRetry,
    this.onDeleteSegment,
    this.onDeleteRecording,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;
  final VoidCallback? onRetry;
  final Future<void> Function(RecordingTranscriptSegment segment)?
  onDeleteSegment;
  final Future<void> Function()? onDeleteRecording;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.recordingRuntime;
    final isLiveSession = runtime.active && runtime.sessionId == session.id;
    final canDeleteRecording = onDeleteRecording != null && !isLiveSession;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          session.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${session.startedAtLabel} • ${session.platformLabel} • ${session.durationLabel}',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: session.statusLabel,
                    color: session.statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: session.sources
                    .map(
                      (source) => _GlassSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        blurSigma: 8,
                        fillColor: _bgCard.withValues(alpha: 0.82),
                        borderColor: _border,
                        child: Text(
                          '${source.label} • ${source.durationLabel}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (session.sources.any(
                (source) => source.mediaKind == 'audio',
              )) ...<Widget>[
                const SizedBox(height: 12),
                _RecordingSourceAudioControls(
                  controller: controller,
                  session: session,
                ),
              ],
              if (session.lastError != null &&
                  session.lastError!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    session.lastError!,
                    style: TextStyle(color: _danger),
                  ),
                ),
              if (session.structuredContent.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _GlassSurface(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(18),
                  blurSigma: 8,
                  fillColor: _accentMuted.withValues(alpha: 0.16),
                  borderColor: _accent.withValues(alpha: 0.26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.auto_awesome, size: 16, color: _accent),
                          const SizedBox(width: 8),
                          Text(
                            'Insights',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (session.structuredContent['summary'] !=
                          null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.structuredContent['summary'].toString(),
                          style: TextStyle(height: 1.55, fontSize: 15),
                        ),
                      ],
                      if (session.structuredContent['action_items'] != null &&
                          _getStructuredList(
                            session,
                            'action_items',
                          ).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          'Action Items',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._getStructuredList(session, 'action_items').map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.toString(),
                                    style: TextStyle(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (session.structuredContent['events'] != null &&
                          _getStructuredList(
                            session,
                            'events',
                          ).isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          'Events Mentioned',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._getStructuredList(session, 'events').map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.toString(),
                                    style: TextStyle(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (session.transcriptSegments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                ...session.transcriptSegments.map(
                  (segment) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GlassSurface(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      borderRadius: BorderRadius.circular(16),
                      blurSigma: 6,
                      fillColor: _bgCard.withValues(alpha: 0.9),
                      borderColor: _border,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 88,
                            child: Text(
                              segment.timestampLabel,
                              style: TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              segment.displayText,
                              style: const TextStyle(
                                height: 1.55,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (onDeleteSegment != null &&
                              segment.id > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                await onDeleteSegment!(segment);
                              },
                              icon: Icon(Icons.delete_outline),
                              tooltip: 'Delete segment',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (session.transcriptText.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _GlassSurface(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(16),
                  blurSigma: 8,
                  fillColor: _bgCard.withValues(alpha: 0.92),
                  borderColor: _border,
                  child: SelectableText(
                    session.transcriptText,
                    style: const TextStyle(height: 1.6, fontSize: 15),
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  session.status == 'processing'
                      ? 'Transcribing...'
                      : session.status == 'failed'
                      ? 'Transcription failed. Check the error above and retry.'
                      : session.status == 'completed'
                      ? 'No transcript text was returned. You can retry transcription.'
                      : 'Transcript is not available yet.',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              if (onRetry != null || canDeleteRecording) ...<Widget>[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (onRetry != null)
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: Icon(Icons.replay),
                        label: Text('Retry transcription'),
                      ),
                    if (canDeleteRecording)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await onDeleteRecording!();
                        },
                        icon: Icon(Icons.delete_forever_outlined),
                        label: Text('Delete recording'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _danger,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _getStructuredList(RecordingSessionItem session, String key) {
    final value = session.structuredContent[key];
    if (value is List) {
      return value;
    }
    return const [];
  }
}

class _RecordingSourceAudioControls extends StatefulWidget {
  const _RecordingSourceAudioControls({
    required this.controller,
    required this.session,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;

  @override
  State<_RecordingSourceAudioControls> createState() =>
      _RecordingSourceAudioControlsState();
}

class _RecordingSourceAudioControlsState
    extends State<_RecordingSourceAudioControls> {
  late final AudioPlayer _player;
  StreamSubscription<void>? _playerCompleteSubscription;
  String? _activeSourceKey;
  bool _isPlaying = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggleSource(RecordingSourceItem source) async {
    final token = ++_loadToken;
    bool isStale() => !mounted || token != _loadToken;
    if (_isPlaying && _activeSourceKey == source.sourceKey) {
      await _player.stop();
      if (isStale()) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
      return;
    }

    try {
      await _player.stop();
      if (isStale()) {
        return;
      }
      final bytes = await widget.controller.fetchRecordingSourceAudioBytes(
        widget.session.id,
        source.sourceKey,
      );
      if (isStale()) {
        return;
      }
      if (bytes.isEmpty) {
        throw StateError('Audio source is empty.');
      }
      final mime = source.mimeType.trim().isNotEmpty
          ? source.mimeType.trim()
          : null;
      await _player.play(BytesSource(bytes, mimeType: mime));
      if (isStale()) {
        await _player.stop();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _activeSourceKey = source.sourceKey;
      });
    } catch (e) {
      if (isStale()) {
        return;
      }
      AppDiagnostics.log(
        'recording.playback',
        'source.play.failed',
        data: <String, Object?>{
          'sessionId': widget.session.id,
          'sourceKey': source.sourceKey,
          'mimeType': source.mimeType,
        },
        error: e,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioSources = widget.session.sources
        .where((source) => source.mediaKind == 'audio')
        .toList();
    if (audioSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: audioSources.map((source) {
        final isActive = _isPlaying && _activeSourceKey == source.sourceKey;
        return AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: isActive ? 1.02 : 1,
          child: OutlinedButton.icon(
            onPressed: () => _toggleSource(source),
            icon: Icon(
              isActive ? Icons.stop_circle_outlined : Icons.play_arrow,
            ),
            label: Text(
              isActive ? 'Stop ${source.label}' : 'Play ${source.label}',
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: isActive
                  ? _accentMuted.withValues(alpha: 0.2)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
