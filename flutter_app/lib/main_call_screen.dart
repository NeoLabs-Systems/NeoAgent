part of 'main.dart';

/// Where a call stands, which decides everything the call screen shows.
enum _CallPhase { ringing, answering, idle, dialing, live, ended }

/// The one call screen: an agent ringing, placing a call, the call itself
/// and the recap after it. Phones show it full screen, the desktop shows it
/// as the voice section, and the launcher embeds it as its home.
class AgentCallScreen extends StatefulWidget {
  const AgentCallScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final NeoAgentController controller;

  /// Inside a screen that owns the chrome and the back gesture (launcher
  /// mode): no minimize control, and the face sizes to the room it gets.
  final bool embedded;

  @override
  State<AgentCallScreen> createState() => _AgentCallScreenState();
}

class _AgentCallScreenState extends State<AgentCallScreen> {
  Timer? _clock;
  bool _pttPressed = false;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _syncClock();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _clock?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncClock();
    setState(() {});
  }

  /// The elapsed time only needs a tick while a call is live.
  void _syncClock() {
    final live = _controller.voiceAssistantLiveState.hasActiveSession;
    if (live == (_clock != null)) return;
    _clock?.cancel();
    _clock = live
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  _CallPhase get _phase {
    final controller = _controller;
    final ringing = controller.incomingAgentCall;
    if (ringing != null) {
      return ringing.accepting ? _CallPhase.answering : _CallPhase.ringing;
    }
    final live = controller.voiceAssistantLiveState;
    if (live.hasActiveSession) return _CallPhase.live;
    if (live.isConnecting || controller.isLiveVoiceCaptureStarting) {
      return _CallPhase.dialing;
    }
    if (controller.lastEndedCall != null) return _CallPhase.ended;
    return _CallPhase.idle;
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final screen = _CallBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                widget.embedded ? 8 : 4,
                28,
                widget.embedded ? 16 : 40,
              ),
              child: LayoutBuilder(
                builder: (context, box) => phase == _CallPhase.ended
                    ? _buildRecap(box)
                    : _buildCall(phase, box),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.embedded) return screen;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      child: screen,
    );
  }

  Widget _buildCall(_CallPhase phase, BoxConstraints box) {
    final controller = _controller;
    final live = controller.voiceAssistantLiveState;
    final faceSize = (box.maxHeight * 0.17).clamp(96.0, 136.0);
    final ringing = phase == _CallPhase.ringing;
    final compact = box.maxHeight < 640;
    final Widget face = phase == _CallPhase.live
        ? _LiveMascot(controller: controller, size: faceSize)
        : NeoMascot(
            mood: ringing ? MascotMood.idle : MascotMood.thinking,
            size: faceSize,
          );
    final showMinimize = !widget.embedded && !ringing;
    return Column(
      children: <Widget>[
        if (showMinimize)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: appStrings.backToChat,
              onPressed: _minimize,
              style: IconButton.styleFrom(
                backgroundColor: _CallColors.control,
                foregroundColor: const Color(0xFFC9D0C1),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        // Who and how the call is going; on a short screen it scales down
        // rather than pushing the controls off.
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _CallStage(
                      mascot: face,
                      size: faceSize,
                      floating: ringing,
                      breathing: phase == _CallPhase.live && live.isSpeaking
                          ? const Duration(milliseconds: 1600)
                          : const Duration(milliseconds: 2800),
                    ),
                    SizedBox(height: compact ? 20 : 36),
                    Text(
                      controller.callAgentName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geist(
                        fontSize: compact ? 32 : 40,
                        height: 1.05,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.2,
                        color: _CallColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._statusLines(phase, live),
                    ..._errors(live),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (ringing) ...<Widget>[
          _CallPillButton(
            icon: Icons.schedule_rounded,
            label: appStrings.callMeLater,
            onTap: () => controller.declineIncomingAgentCall(later: true),
          ),
          SizedBox(height: compact ? 24 : 44),
        ],
        _buildControls(phase),
      ],
    );
  }

  List<Widget> _statusLines(_CallPhase phase, VoiceAssistantLiveState live) {
    final muted = GoogleFonts.geist(fontSize: 16, color: _CallColors.textMuted);
    switch (phase) {
      case _CallPhase.ringing:
        return <Widget>[Text(appStrings.incomingCall, style: muted)];
      case _CallPhase.answering:
      case _CallPhase.dialing:
        return <Widget>[
          Text(
            phase == _CallPhase.dialing
                ? appStrings.callingEllipsis
                : appStrings.connecting,
            style: muted,
          ),
        ];
      case _CallPhase.idle:
        return <Widget>[Text(appStrings.voiceCall, style: muted)];
      case _CallPhase.ended:
        return const <Widget>[];
      case _CallPhase.live:
        final startedAt = _controller.liveVoiceSessionStartedAt;
        return <Widget>[
          Text(
            _formatCallDuration(
              startedAt == null
                  ? Duration.zero
                  : DateTime.now().difference(startedAt),
            ),
            style: GoogleFonts.geistMono(
              fontSize: 16,
              color: _CallColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _liveLabel(live),
            style: GoogleFonts.geist(fontSize: 14, color: _CallColors.accent),
          ),
          if (live.hasActiveTask) ...<Widget>[
            const SizedBox(height: 16),
            _BackgroundTaskLine(
              request: live.activeTaskRequest,
              onCancel: _controller.cancelLiveVoiceTask,
            ),
          ],
        ];
    }
  }

  String _liveLabel(VoiceAssistantLiveState live) {
    if (live.transportState != 'connected' || live.state == 'reconnecting') {
      return appStrings.reconnectingCall;
    }
    if (live.isSpeaking) return appStrings.speaking;
    if (_controller.isLiveVoiceCaptureActive) return appStrings.listening;
    if (live.hasActiveTask) return appStrings.agentWorking;
    return live.isHandsFree ? appStrings.micMuted : appStrings.holdToTalk2;
  }

  List<Widget> _errors(VoiceAssistantLiveState live) {
    final voiceError = live.error?.trim() ?? '';
    final globalError = _controller.errorMessage?.trim() ?? '';
    return <Widget>[
      if (globalError.isNotEmpty && globalError != voiceError) ...<Widget>[
        const SizedBox(height: 16),
        _InlineError(
          message: globalError,
          onDismiss: _controller.clearInlineError,
        ),
      ],
      if (voiceError.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        _InlineError(message: voiceError),
      ],
    ];
  }

  Widget _buildControls(_CallPhase phase) {
    final controller = _controller;
    switch (phase) {
      case _CallPhase.ringing:
        return _controlRow(<Widget>[
          _CallButton(
            icon: Icons.call_end_rounded,
            label: appStrings.decline,
            size: 72,
            color: _CallColors.decline,
            onTap: () => controller.declineIncomingAgentCall(),
          ),
          _CallButton(
            icon: Icons.call_rounded,
            label: appStrings.answerCall,
            size: 72,
            color: _CallColors.answer,
            onTap: controller.acceptIncomingAgentCall,
          ),
        ], spread: true);
      case _CallPhase.answering:
        return _controlRow(<Widget>[
          _endButton(onTap: () => controller.declineIncomingAgentCall()),
        ]);
      case _CallPhase.dialing:
        return _controlRow(<Widget>[
          _endButton(onTap: controller.hangUpVoiceCall),
        ]);
      case _CallPhase.idle:
      case _CallPhase.ended:
        return _controlRow(<Widget>[
          _CallButton(
            icon: Icons.call_rounded,
            label: appStrings.call,
            size: 72,
            color: _CallColors.answer,
            onTap: _placeCall,
          ),
        ]);
      case _CallPhase.live:
        return _controlRow(<Widget>[
          _talkButton(),
          _endButton(onTap: _endCall),
          if (CallBridge.supportsSpeakerphone)
            _CallButton(
              icon: Icons.volume_up_rounded,
              label: appStrings.speakerphone,
              selected: controller.callSpeakerphoneOn,
              onTap: controller.toggleCallSpeakerphone,
            ),
        ], spread: true);
    }
  }

  Widget _controlRow(List<Widget> buttons, {bool spread = false}) {
    return Row(
      mainAxisAlignment: spread && buttons.length > 1
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons,
    );
  }

  Widget _endButton({required VoidCallback? onTap}) => _CallButton(
    icon: Icons.call_end_rounded,
    label: appStrings.end,
    size: 72,
    color: _CallColors.decline,
    onTap: onTap,
  );

  /// Hands-free calls mute and unmute; push-to-talk calls are held.
  Widget _talkButton() {
    final controller = _controller;
    if (controller.voiceAssistantLiveState.isHandsFree) {
      final muted = !controller.isLiveVoiceCaptureActive;
      return _CallButton(
        icon: muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
        label: muted ? appStrings.unmuteMic : appStrings.muteMic,
        selected: muted,
        onTap: () => unawaited(_guard(controller.toggleLiveVoiceCapture)),
      );
    }
    final holding = controller.isLiveVoiceCaptureEngaged || _pttPressed;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => unawaited(_startHold()),
      onPointerUp: (_) => unawaited(controller.stopLiveVoiceCapture()),
      onPointerCancel: (_) => unawaited(controller.stopLiveVoiceCapture()),
      child: _CallButton(
        icon: holding ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
        label: holding ? appStrings.releaseToSend : appStrings.holdToTalk2,
        selected: holding,
        // The pointer listener drives it; this only marks it enabled.
        onTap: () {},
      ),
    );
  }

  Future<void> _startHold() async {
    final controller = _controller;
    if (controller.isLiveVoiceCaptureActive ||
        controller.isLiveVoiceCaptureStarting) {
      return;
    }
    setState(() => _pttPressed = true);
    await _guard(controller.startLiveVoiceCapture);
    if (mounted) setState(() => _pttPressed = false);
  }

  Widget _buildRecap(BoxConstraints box) {
    final ended = _controller.lastEndedCall!;
    final task = ended.backgroundTask;
    final faceSize = (box.maxHeight * 0.13).clamp(72.0, 104.0);
    return Column(
      children: <Widget>[
        const Spacer(),
        NeoMascot(mood: MascotMood.done, size: faceSize),
        const SizedBox(height: 28),
        Text(
          appStrings.callEnded,
          style: GoogleFonts.geist(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: _CallColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${ended.agentName} · ${_formatCallDuration(ended.duration)}',
          textAlign: TextAlign.center,
          style: GoogleFonts.geistMono(
            fontSize: 14,
            color: _CallColors.textMuted,
          ),
        ),
        if (task != null) ...<Widget>[
          const SizedBox(height: 32),
          _BackgroundTaskLine(request: task),
        ],
        const Spacer(flex: 2),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _openConversation,
            style: FilledButton.styleFrom(
              backgroundColor: _CallColors.accent,
              foregroundColor: const Color(0xFF1A1406),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(appStrings.openConversation),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _placeCall,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: Text(appStrings.callBack),
            style: OutlinedButton.styleFrom(
              foregroundColor: _CallColors.text,
              side: const BorderSide(color: _CallColors.controlBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _placeCall() => _guard(_controller.startVoiceCall);

  /// A call with work still running asks whether that work should go on.
  Future<void> _endCall() async {
    final controller = _controller;
    if (!controller.voiceAssistantLiveState.hasActiveTask) {
      await controller.hangUpVoiceCall();
      return;
    }
    final cancelTask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appStrings.endVoiceCall),
        content: Text(appStrings.neoagentIsStillWorkingOnA),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appStrings.stayOnTheCall),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appStrings.keepTaskRunning),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appStrings.cancelTask),
          ),
        ],
      ),
    );
    if (cancelTask == null || !mounted) return;
    await controller.hangUpVoiceCall(cancelTask: cancelTask);
  }

  /// The call keeps running; the chat is where the conversation lives.
  void _minimize() {
    _controller.dismissCallRecap();
    _controller.setSelectedSection(AppSection.chat);
  }

  void _openConversation() {
    _controller.dismissCallRecap();
    _controller.setSelectedSection(AppSection.chat);
  }

  /// The controller records failures on the live state, which the screen
  /// shows; nothing more to do here.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}

/// The work an agent carries on with during or after a call.
class _BackgroundTaskLine extends StatelessWidget {
  const _BackgroundTaskLine({required this.request, this.onCancel});

  final String request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final text = request.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, onCancel == null ? 16 : 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CallColors.controlBorder),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: _CallColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.isEmpty
                  ? appStrings.workingOnATaskInTheBackground
                  : appStrings.workingInTheBackgroundArg1(text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC9D0C1),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: _CallColors.textMuted,
              ),
              child: Text(appStrings.cancel),
            ),
        ],
      ),
    );
  }
}
