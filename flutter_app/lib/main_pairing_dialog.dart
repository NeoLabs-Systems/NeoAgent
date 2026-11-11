part of 'main.dart';

// Settings › Sign-in & security › Pair a phone: a QR code the NeoAgent app
// on a phone scans to sign in to this account
// (server/services/account/pairing.js). The code lives five minutes; the
// dialog counts down and polls until a phone redeemed it.

/// How often the dialog asks whether the code was used.
const Duration _pairingPollInterval = Duration(seconds: 2);

/// The longest a code is shown, whatever the server's clock says.
const Duration _pairingLifetime = Duration(minutes: 5);

Future<void> showPairPhoneDialog(
  BuildContext context,
  NeoAgentController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => PairPhoneDialog(
    start: controller.startPairing,
    poll: controller.pairingStatus,
    friendlyError: controller.friendlyError,
  ),
);

class PairPhoneDialog extends StatefulWidget {
  const PairPhoneDialog({
    super.key,
    required this.start,
    required this.poll,
    required this.friendlyError,
    this.now = DateTime.now,
  });

  final Future<PairingTicket> Function() start;
  final Future<PairingStatus> Function(String code) poll;
  final String Function(Object error) friendlyError;

  /// The clock the countdown reads; tests pass their own.
  final DateTime Function() now;

  @override
  State<PairPhoneDialog> createState() => _PairPhoneDialogState();
}

class _PairPhoneDialogState extends State<PairPhoneDialog> {
  PairingTicket? _ticket;
  DateTime? _deadline;
  PairingStatus? _status;
  String? _error;
  Timer? _tick;
  Timer? _pollTimer;
  bool _polling = false;

  Duration get _left => _deadline == null
      ? Duration.zero
      : _deadline!.difference(widget.now());

  bool get _expired =>
      _status?.state == PairingState.expired ||
      (_ticket != null && _left <= Duration.zero);

  bool get _paired => _status?.state == PairingState.used;

  @override
  void initState() {
    super.initState();
    unawaited(_newCode());
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _tick?.cancel();
    _pollTimer?.cancel();
  }

  Future<void> _newCode() async {
    _stopTimers();
    setState(() {
      _ticket = null;
      _status = null;
      _error = null;
    });
    try {
      final ticket = await widget.start();
      if (!mounted) return;
      final now = widget.now();
      var left = ticket.expiresAt.difference(now);
      // A server clock ahead of or behind ours must not cut the code short.
      if (left <= Duration.zero || left > _pairingLifetime) {
        left = _pairingLifetime;
      }
      setState(() {
        _ticket = ticket;
        _deadline = now.add(left);
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      _pollTimer = Timer.periodic(
        _pairingPollInterval,
        (_) => unawaited(_poll()),
      );
    } catch (error) {
      if (mounted) setState(() => _error = widget.friendlyError(error));
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    if (_expired) _stopTimers();
  }

  Future<void> _poll() async {
    final ticket = _ticket;
    if (ticket == null || _polling || _paired) return;
    _polling = true;
    try {
      final status = await widget.poll(ticket.code);
      if (!mounted || ticket != _ticket) return;
      setState(() => _status = status);
      if (status.state != PairingState.pending) _stopTimers();
    } catch (_) {
      // A missed poll is retried on the next tick.
    } finally {
      _polling = false;
    }
  }

  Widget _qr(PairingTicket ticket) {
    return Semantics(
      label: appStrings.pairQrSemantics,
      image: true,
      child: Opacity(
        opacity: _expired ? 0.15 : (_paired ? 0.35 : 1),
        child: _AuthQrPlate(
          size: 232,
          payload: ticket.qrPayload,
          preparing: false,
        ),
      ),
    );
  }

  Widget _statusLine() {
    if (_paired) {
      return Text(
        appStrings.pairPairedWith(
          _status?.deviceName ?? appStrings.pairUnknownDevice,
        ),
        textAlign: TextAlign.center,
        style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      );
    }
    if (_expired) {
      return Center(
        child: _StatusPill(label: appStrings.pairExpired, color: _textMuted),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: <Widget>[
        _StatusPill(label: appStrings.pairWaiting, color: _info),
        Text(
          appStrings.pairExpiresIn(formatCountdown(_left)),
          key: const ValueKey<String>('pair-countdown'),
          style: GoogleFonts.geistMono(fontSize: 13, color: _textSecondary),
        ),
      ],
    );
  }

  Widget _fallbackLink(PairingTicket ticket) {
    final server = Uri.tryParse(ticket.server);
    if (server == null || server.host.isEmpty) return const SizedBox.shrink();
    final link = pairingWebLink(server, ticket.code).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          appStrings.pairCantScan,
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                link,
                maxLines: 2,
                style: GoogleFonts.geistMono(
                  fontSize: 11.5,
                  color: _textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: appStrings.copy,
              onPressed: () =>
                  unawaited(Clipboard.setData(ClipboardData(text: link))),
              icon: const Icon(Icons.copy_rounded, size: 16),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(appStrings.pairTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                appStrings.pairInstructions,
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) _InlineError(message: _error!),
              if (ticket == null && _error == null)
                const SizedBox(
                  height: 232,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (ticket != null) ...<Widget>[
                Center(child: _qr(ticket)),
                const SizedBox(height: AppSpacing.md),
                _statusLine(),
                if (!_paired && !_expired) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: _border),
                  const SizedBox(height: AppSpacing.sm),
                  _fallbackLink(ticket),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (_expired || _error != null)
          OutlinedButton(
            onPressed: () => unawaited(_newCode()),
            child: Text(appStrings.pairNewCode),
          ),
        if (_paired)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appStrings.done),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appStrings.close),
          ),
      ],
    );
  }
}
