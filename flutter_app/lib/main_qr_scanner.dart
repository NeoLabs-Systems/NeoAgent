part of 'main.dart';

// The full-screen QR scanner of the iOS and Android apps, for both
// directions of QR pairing: a pairing code a signed-in screen shows (this
// phone signs in), and a sign-in request a signed-out screen or the wearable
// shows (this signed-in phone approves it). It explains the camera before
// the system asks for it, and says when a code is not the kind it wants.

/// Whether this device scans QR codes with its camera.
bool get qrScannerSupported => _isMobileDevice();

/// Opens the camera full screen until [parse] accepts a code. [hint] says
/// where the code is and [wrongCode] what a code [parse] refuses is not.
/// Resolves to null when the user backs out.
Future<T?> scanQrCode<T extends Object>(
  BuildContext context, {
  required T? Function(String raw) parse,
  required String hint,
  required String wrongCode,
}) => Navigator.of(context).push<T>(
  MaterialPageRoute<T>(
    fullscreenDialog: true,
    builder: (_) =>
        _QrScanPage<T>(parse: parse, hint: hint, wrongCode: wrongCode),
  ),
);

/// Scans a pairing code from a signed-in screen.
Future<PairingLinkData?> scanPairingCode(BuildContext context) =>
    scanQrCode<PairingLinkData>(
      context,
      parse: parsePairingLink,
      hint: appStrings.scanPairingHint,
      wrongCode: appStrings.scanWrongPairingCode,
    );

/// Scans a sign-in request from a signed-out screen or the wearable.
Future<QrLoginScanPayload?> scanQrLoginRequest(BuildContext context) =>
    scanQrCode<QrLoginScanPayload>(
      context,
      parse: QrLoginScanPayload.tryParse,
      hint: appStrings.pointTheCameraAtTheCode,
      wrongCode: appStrings.thatQrCodeIsNotA,
    );

enum _ScanState { priming, scanning, denied, failed }

/// The camera is a dark surface in either theme.
const NeoAgentPalette _scanPalette = darkPalette;

class _QrScanPage<T extends Object> extends StatefulWidget {
  const _QrScanPage({
    required this.parse,
    required this.hint,
    required this.wrongCode,
  });

  final T? Function(String raw) parse;
  final String hint;
  final String wrongCode;

  @override
  State<_QrScanPage<T>> createState() => _QrScanPageState<T>();
}

class _QrScanPageState<T extends Object> extends State<_QrScanPage<T>> {
  final MobileScannerController _camera = MobileScannerController(
    autoStart: false,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  _ScanState _state = _ScanState.priming;
  bool _wrongCode = false;
  Timer? _wrongCodeTimer;
  bool _done = false;

  @override
  void dispose() {
    _wrongCodeTimer?.cancel();
    unawaited(_camera.dispose());
    super.dispose();
  }

  /// Starting the camera is what triggers the system prompt, so it only
  /// happens after the user read why it is needed.
  Future<void> _start() async {
    setState(() => _state = _ScanState.scanning);
    try {
      await _camera.start();
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      setState(
        () => _state =
            error.errorCode == MobileScannerErrorCode.permissionDenied
            ? _ScanState.denied
            : _ScanState.failed,
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final result = widget.parse(barcode.rawValue ?? '');
      if (result != null) {
        _done = true;
        unawaited(_camera.stop());
        Navigator.of(context).pop(result);
        return;
      }
    }
    if (capture.barcodes.isEmpty) return;
    _wrongCodeTimer?.cancel();
    setState(() => _wrongCode = true);
    _wrongCodeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _wrongCode = false);
    });
  }

  /// iOS opens the app's own settings page; Android has no such link, so
  /// the text says where to go.
  Future<void> _openSettings() =>
      url_launcher.launchUrl(Uri.parse('app-settings:'));

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: _scanPalette.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _scanPalette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: _scanPalette.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _scanner() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MobileScanner(
          controller: _camera,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _message(
            icon: Icons.no_photography_outlined,
            title: appStrings.scanFailedTitle,
            body: appStrings.scanFailedBody,
            actions: const <Widget>[],
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: _scanPalette.textPrimary, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Column(
            children: <Widget>[
              Text(
                _wrongCode ? widget.wrongCode : widget.hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _scanPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (context, state, _) {
                  if (state.torchState == TorchState.unavailable) {
                    return const SizedBox.shrink();
                  }
                  final on = state.torchState == TorchState.on;
                  return IconButton.filledTonal(
                    tooltip: on
                        ? appStrings.scanTorchOff
                        : appStrings.scanTorchOn,
                    onPressed: () => unawaited(_camera.toggleTorch()),
                    icon: Icon(
                      on
                          ? Icons.flashlight_off_rounded
                          : Icons.flashlight_on_rounded,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_state) {
      case _ScanState.priming:
        return _message(
          icon: Icons.qr_code_scanner_rounded,
          title: appStrings.scanPrimeTitle,
          body: appStrings.scanPrimeBody,
          actions: <Widget>[
            FilledButton(
              onPressed: () => unawaited(_start()),
              child: Text(appStrings.scanPrimeAllow),
            ),
          ],
        );
      case _ScanState.scanning:
        return _scanner();
      case _ScanState.denied:
        return _message(
          icon: Icons.no_photography_outlined,
          title: appStrings.scanDeniedTitle,
          body: _isIos
              ? appStrings.scanDeniedBodyIos
              : appStrings.scanDeniedBodyAndroid,
          actions: <Widget>[
            if (_isIos)
              FilledButton(
                onPressed: () => unawaited(_openSettings()),
                child: Text(appStrings.scanOpenSettings),
              )
            else
              FilledButton(
                onPressed: () => unawaited(_start()),
                child: Text(appStrings.retry),
              ),
          ],
        );
      case _ScanState.failed:
        return _message(
          icon: Icons.no_photography_outlined,
          title: appStrings.scanFailedTitle,
          body: appStrings.scanFailedBody,
          actions: <Widget>[
            FilledButton(
              onPressed: () => unawaited(_start()),
              child: Text(appStrings.retry),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scanPalette.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _scanPalette.textPrimary,
        elevation: 0,
        title: Text(appStrings.scanTitle),
      ),
      extendBodyBehindAppBar: _state == _ScanState.scanning,
      body: SafeArea(top: _state != _ScanState.scanning, child: _body()),
    );
  }
}

/// Scans a signed-in screen's pairing code and signs in with it.
Future<void> _scanAndPair(
  BuildContext context,
  NeoAgentController controller,
) async {
  controller.clearInlineError();
  final link = await scanPairingCode(context);
  if (link != null) await controller.pairWithLink(link);
}

/// "Scan QR code", with the line that says where the code is: how a phone
/// signs in without typing a server or a password.
class _ScanToPairButton extends StatelessWidget {
  const _ScanToPairButton({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isAuthenticating || controller.isSavingBackendUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => unawaited(_scanAndPair(context, controller)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: _textPrimary,
            side: BorderSide(color: _borderLight),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text(appStrings.signInScanQr),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          appStrings.signInScanQrHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textMuted, fontSize: 12.5, height: 1.4),
        ),
      ],
    );
  }
}
