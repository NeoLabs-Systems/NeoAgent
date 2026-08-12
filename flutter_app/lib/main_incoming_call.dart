part of 'main.dart';

class IncomingAgentCall {
  const IncomingAgentCall({
    required this.callId,
    required this.agentId,
    required this.agentName,
    required this.expiresAt,
    this.accepting = false,
  });

  factory IncomingAgentCall.fromJson(Map<String, dynamic> json) {
    return IncomingAgentCall(
      callId: json['callId']?.toString().trim() ?? '',
      agentId: json['agentId']?.toString().trim() ?? '',
      agentName:
          json['agentName']?.toString().trim().ifEmpty('NeoAgent') ??
          'NeoAgent',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(seconds: 30)),
    );
  }

  final String callId;
  final String agentId;
  final String agentName;
  final DateTime expiresAt;
  final bool accepting;

  IncomingAgentCall copyWith({bool? accepting}) {
    return IncomingAgentCall(
      callId: callId,
      agentId: agentId,
      agentName: agentName,
      expiresAt: expiresAt,
      accepting: accepting ?? this.accepting,
    );
  }
}

class IncomingAgentCallOverlay extends StatefulWidget {
  const IncomingAgentCallOverlay({
    super.key,
    required this.call,
    required this.controller,
  });

  final IncomingAgentCall call;
  final NeoAgentController controller;

  @override
  State<IncomingAgentCallOverlay> createState() =>
      _IncomingAgentCallOverlayState();
}

class _IncomingAgentCallOverlayState extends State<IncomingAgentCallOverlay> {
  Timer? _ticker;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _playRing();
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) => _playRing());
  }

  @override
  void didUpdateWidget(covariant IncomingAgentCallOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.call.callId != widget.call.callId) _playRing();
  }

  void _playRing() {
    if (widget.call.accepting) return;
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(HapticFeedback.mediumImpact());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(
      0,
      widget.call.expiresAt.difference(DateTime.now()).inSeconds,
    );
    return Material(
      key: const Key('incoming-agent-call-overlay'),
      color: const Color(0xFF07110D),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.15,
            colors: <Color>[Color(0xFF284A3B), Color(0xFF07110D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: <Widget>[
                Text(
                  widget.call.accepting
                      ? 'CONNECTING'
                      : 'INCOMING NEOAGENT CALL',
                  style: const TextStyle(
                    color: Color(0xFFB8C9C0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE0B86B).withValues(alpha: 0.16),
                    border: Border.all(
                      color: const Color(0xFFE0B86B).withValues(alpha: 0.52),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 58,
                    color: Color(0xFFE0B86B),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.call.agentName,
                  key: const Key('incoming-agent-name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.call.accepting
                      ? 'Preparing the private voice session…'
                      : 'Wants to talk with you · ${remaining}s',
                  style: const TextStyle(
                    color: Color(0xFFB8C9C0),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _IncomingCallAction(
                      key: const Key('decline-agent-call'),
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      color: const Color(0xFFD84A4A),
                      onTap: widget.call.accepting
                          ? null
                          : widget.controller.declineIncomingAgentCall,
                    ),
                    _IncomingCallAction(
                      key: const Key('accept-agent-call'),
                      icon: Icons.call_rounded,
                      label: widget.call.accepting ? 'Connecting' : 'Accept',
                      color: const Color(0xFF39A96B),
                      onTap: widget.call.accepting
                          ? null
                          : widget.controller.acceptIncomingAgentCall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingCallAction extends StatelessWidget {
  const _IncomingCallAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        IconButton.filled(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.45),
            minimumSize: const Size(72, 72),
          ),
          icon: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
