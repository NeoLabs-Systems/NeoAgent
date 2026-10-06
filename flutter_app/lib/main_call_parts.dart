part of 'main.dart';

/// A call the agent placed that is ringing on this device.
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

/// What the call screen recaps once a call is over.
class EndedAgentCall {
  const EndedAgentCall({
    required this.agentName,
    required this.duration,
    this.backgroundTask,
  });

  final String agentName;
  final Duration duration;

  /// The task the agent kept working on after the call, if any; empty when
  /// it has no description.
  final String? backgroundTask;
}

/// Colours of the call screen. A call always looks like a phone call, dark
/// whatever the app theme, so these do not follow the palette.
abstract final class _CallColors {
  static const Color backdropTop = Color(0xFF121B15);
  static const Color backdrop = Color(0xFF0B110D);
  static const Color text = Color(0xFFECEFE5);
  static const Color textMuted = Color(0xFF8D9886);
  static const Color accent = Color(0xFFE1B052);
  static const Color control = Color(0x14E0F0E0);
  static const Color controlBorder = Color(0x1FE0F0E0);
  static const Color answer = Color(0xFF5FB06A);
  static const Color decline = Color(0xFFD9705C);
}

String _formatCallDuration(Duration duration) {
  final totalSeconds = math.max(0, duration.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// The dark backdrop every call screen sits on.
class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A Material of its own: the screen also rings above the app's scaffold.
    return Material(
      color: _CallColors.backdrop,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, 0.1),
            colors: <Color>[_CallColors.backdropTop, _CallColors.backdrop],
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: _CallColors.text),
          child: child,
        ),
      ),
    );
  }
}

/// The caller's face with a soft glow that breathes behind it — slowly while
/// ringing, faster while the call is live.
class _CallStage extends StatefulWidget {
  const _CallStage({
    required this.mascot,
    required this.size,
    this.breathing = const Duration(milliseconds: 2800),
    this.floating = false,
  });

  final Widget mascot;

  /// Edge of the face; the glow is about 1.6 times that.
  final double size;
  final Duration breathing;

  /// Whether the face also drifts up and down, as it does while ringing.
  final bool floating;

  @override
  State<_CallStage> createState() => _CallStageState();
}

class _CallStageState extends State<_CallStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: widget.breathing,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_CallStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathing != widget.breathing) {
      _breath.duration = widget.breathing;
      if (_breath.isAnimating) _breath.repeat(reverse: true);
    }
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
      _breath.value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = widget.size * 1.62;
    return SizedBox.square(
      dimension: extent,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_breath.value);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 0.94 + 0.1 * t,
                child: Opacity(
                  opacity: 0.55 + 0.45 * t,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          _CallColors.accent.withValues(alpha: 0.22),
                          _CallColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, widget.floating ? -6 * t : 0),
                child: child,
              ),
            ],
          );
        },
        child: widget.mascot,
      ),
    );
  }
}

/// A round call control with its label underneath.
class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 64,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  /// A solid fill for Answer, Decline and End; otherwise a quiet glass fill.
  final Color? color;

  /// A toggle that is on, like a muted microphone or the speaker.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fill = color ?? (selected ? _CallColors.text : _CallColors.control);
    final iconColor = color != null
        ? Colors.white
        : selected
        ? _CallColors.backdrop
        : _CallColors.text;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: color == null ? selected : null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: math.max(size, 84),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(icon, size: size * 0.4, color: iconColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _CallColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet pill-shaped secondary action, like "Call me later".
class _CallPillButton extends StatelessWidget {
  const _CallPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC9D0C1),
        backgroundColor: const Color(0x0AE0F0E0),
        side: const BorderSide(color: _CallColors.controlBorder),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
