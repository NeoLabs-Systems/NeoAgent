part of 'main.dart';

/// The voice call on a phone: full screen and laid out like a phone call —
/// who you are talking to and for how long up top, live captions in the
/// middle, call controls and the call/end button at the thumb.
extension _PhoneCallLayout on _VoiceAssistantPanelState {
  Widget _buildPhoneCall(BuildContext context) {
    final controller = widget.controller;
    final liveState = controller.voiceAssistantLiveState;
    final inCall = liveState.hasActiveSession;
    final dialing =
        !inCall &&
        (liveState.isConnecting || controller.isLiveVoiceCaptureStarting);
    final capturing = controller.isLiveVoiceCaptureEngaged || _pttPressed;
    final voiceError = liveState.error?.trim() ?? '';
    final globalError = controller.errorMessage?.trim() ?? '';
    final caption = liveState.timeline.isEmpty ? null : liveState.timeline.last;
    final name = controller.agentProfiles.length > 1
        ? controller.activeAgentLabel
        : 'NeoAgent';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leavePhoneCall();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.42),
            radius: 1.05,
            colors: <Color>[
              _accent.withValues(alpha: inCall ? 0.14 : 0.08),
              _bgPrimary.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Back to chat',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      iconSize: 30,
                      color: _textSecondary,
                      onPressed: _leavePhoneCall,
                    ),
                    Expanded(
                      child: Text(
                        'VOICE CALL',
                        textAlign: TextAlign.center,
                        style: _sectionEyebrowStyle(),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const Spacer(flex: 2),
                _CallHalo(
                  pulseColor: !inCall
                      ? null
                      : liveState.isSpeaking
                      ? _accent
                      : capturing
                      ? _success
                      : null,
                  child: _LiveMascot(controller: controller, size: 128),
                ),
                const SizedBox(height: 28),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTitleStyle(34),
                ),
                const SizedBox(height: 8),
                Text(
                  _phoneCallStatus(controller, liveState, dialing: dialing),
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 72,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: caption == null
                          ? const SizedBox.shrink()
                          : Text(
                              caption.content.trim(),
                              key: ValueKey<String>(caption.id),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: caption.role == 'assistant'
                                    ? _textPrimary
                                    : _textSecondary,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: <Widget>[
                      if (liveState.hasActiveTask) ...<Widget>[
                        _buildTaskBanner(controller),
                        const SizedBox(height: 12),
                      ],
                      if (globalError.isNotEmpty &&
                          globalError != voiceError) ...<Widget>[
                        _InlineError(
                          message: globalError,
                          onDismiss: controller.clearInlineError,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (voiceError.isNotEmpty) ...<Widget>[
                        _InlineError(message: voiceError),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                if (inCall) ...<Widget>[
                  _buildPhoneCallControls(controller, capturing: capturing),
                  const SizedBox(height: 28),
                ],
                if (inCall || dialing)
                  _CallRoundButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    size: 76,
                    color: _danger,
                    foreground: Colors.white,
                    onTap: inCall ? () => _endSession(controller) : null,
                  )
                else
                  _CallRoundButton(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    size: 76,
                    color: _success,
                    foreground: Colors.white,
                    onTap: _placePhoneCall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneCallControls(
    NeoAgentController controller, {
    required bool capturing,
  }) {
    final liveState = controller.voiceAssistantLiveState;
    final Widget talk;
    if (_handsFree(controller)) {
      final muted = !controller.isLiveVoiceCaptureActive;
      talk = _CallRoundButton(
        icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: muted ? 'Unmute' : 'Mute',
        selected: muted,
        onTap: _toggleCapture,
      );
    } else {
      talk = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePrimaryPointerDown,
        onPointerUp: _handlePrimaryPointerUp,
        onPointerCancel: _handlePrimaryPointerUp,
        child: _CallRoundButton(
          icon: capturing ? Icons.graphic_eq_rounded : Icons.mic_rounded,
          label: capturing ? 'Release to send' : 'Hold to talk',
          color: capturing ? _success : _accent,
          foreground: _bgPrimary,
          enabled: true,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CallRoundButton(
          icon: Icons.subject_rounded,
          label: 'Transcript',
          onTap: () => _showPhoneCallTranscript(controller),
        ),
        talk,
        _CallRoundButton(
          icon: Icons.voice_over_off_rounded,
          label: 'Stop speaking',
          onTap: liveState.isSpeaking ? controller.stopLiveVoicePlayback : null,
        ),
      ],
    );
  }

  String _phoneCallStatus(
    NeoAgentController controller,
    VoiceAssistantLiveState liveState, {
    required bool dialing,
  }) {
    if (dialing) return 'Calling…';
    if (!liveState.hasActiveSession) return 'Voice call';
    return '${_callElapsedLabel(controller)} · '
        '${_liveStateLabel(controller, liveState)}';
  }

  Future<void> _placePhoneCall() async {
    try {
      await widget.controller.startVoiceCall();
    } catch (_) {
      // The controller records the error on the live state.
    }
  }

  /// The call keeps running; the chat composer is where it was started.
  void _leavePhoneCall() {
    widget.controller.setSelectedSection(AppSection.chat);
  }

  void _showPhoneCallTranscript(NeoAgentController controller) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.panel),
          ),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (_, scrollController) => ListenableBuilder(
            listenable: controller,
            builder: (_, _) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('TRANSCRIPT', style: _sectionEyebrowStyle()),
                const SizedBox(height: 12),
                _buildTimeline(controller.voiceAssistantLiveState),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A phone-call control: a round button with its label underneath.
class _CallRoundButton extends StatelessWidget {
  const _CallRoundButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled,
    this.size = 64,
    this.color,
    this.foreground,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Defaults to having [onTap]; a hold-to-talk button handles its own
  /// pointer events and has none.
  final bool? enabled;
  final double size;
  final Color? color;
  final Color? foreground;

  /// Toggled on, like a muted microphone.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled ?? onTap != null;
    final background = color ?? (selected ? _textPrimary : _bgTertiary);
    final iconColor = foreground ?? (selected ? _bgPrimary : _textPrimary);
    return Semantics(
      button: true,
      enabled: interactive,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: interactive ? 1 : 0.4,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: color == null && !selected
                      ? Border.all(color: _borderLight)
                      : null,
                  boxShadow: color == null
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: background.withValues(alpha: 0.28),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(icon, size: size * 0.42, color: iconColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ring around the caller's face that ripples outward in [pulseColor]
/// while someone is talking, and rests as a hairline otherwise.
class _CallHalo extends StatefulWidget {
  const _CallHalo({required this.child, this.pulseColor});

  final Widget child;
  final Color? pulseColor;

  @override
  State<_CallHalo> createState() => _CallHaloState();
}

class _CallHaloState extends State<_CallHalo>
    with SingleTickerProviderStateMixin {
  static const double _extent = 216;
  static const double _ring = 166;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_CallHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final pulsing =
        widget.pulseColor != null && !MediaQuery.disableAnimationsOf(context);
    if (pulsing && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!pulsing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pulseColor;
    return SizedBox.square(
      dimension: _extent,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (color != null)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  for (final phase in <double>[0, 0.5])
                    _ripple(color, (_pulse.value + phase) % 1),
                ],
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _ring,
            height: _ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color?.withValues(alpha: 0.6) ?? _borderLight,
                width: 1.5,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  Widget _ripple(Color color, double t) {
    final side = _ring + (_extent - _ring) * t;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16 * (1 - t)),
      ),
    );
  }
}
