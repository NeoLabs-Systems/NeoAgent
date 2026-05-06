part of 'main.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.6),
          radius: 1.3,
          colors: <Color>[_accent, _bgSecondary, _bgPrimary],
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _BrandLockup(logoSize: 52),
              SizedBox(height: 18),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading NeoOS'),
            ],
          ),
        ),
      ),
    );
  }
}

class BackendSetupView extends StatefulWidget {
  const BackendSetupView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<BackendSetupView> createState() => _BackendSetupViewState();
}

class _BackendSetupViewState extends State<BackendSetupView> {
  late final TextEditingController _backendUrlController;

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(
      text: widget.controller.backendUrl,
    );
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.controller.saveBackendUrl(_backendUrlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _EntranceMotion(
                  child: _GlassSurface(
                    borderRadius: BorderRadius.circular(34),
                    blurSigma: 28,
                    boxShadow: _softPanelShadow,
                    overlayGradient: _panelGradient,
                    fillColor: _glassFill,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 32, 34, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const _BrandLockup(logoSize: 60),
                          const SizedBox(height: 22),
                          Text(
                            'FIRST-RUN SETUP',
                            style: _sectionEyebrowStyle(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Connect this build to your NeoAgent backend',
                            style: _displayTitleStyle(34),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This build was not bundled with a backend endpoint. Enter your NeoAgent server URL once and the app will store it locally for future launches.',
                            style: TextStyle(
                              color: _textSecondary,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _backendUrlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Backend URL',
                              hintText: 'https://neoagent.example.com',
                              prefixIcon: Icon(Icons.cloud_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _bgSecondary.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _borderLight),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.privacy_tip_outlined,
                                  color: _accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Use your hosted NeoAgent URL. If you enter a hostname without a scheme, the app will infer `https://` for remote hosts and `http://` for local addresses.',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (controller.errorMessage
                              case final message?) ...<Widget>[
                            const SizedBox(height: 16),
                            _InlineError(message: message),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: controller.isSavingBackendUrl
                                  ? null
                                  : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: controller.isSavingBackendUrl
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                controller.isSavingBackendUrl
                                    ? 'Connecting...'
                                    : 'Connect Backend',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _twoFactorController;
  bool _registerMode = false;
  bool _qrAutoRequestedForVisibleMode = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.controller.username,
    );
    _emailController = TextEditingController(
      text: widget.controller.user?['email']?.toString() ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.controller.password,
    );
    _confirmPasswordController = TextEditingController();
    _twoFactorController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final accountController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    String? inlineError;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: _bgCard,
                title: Text('Reset password'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Enter your username or account email. NeoOS will send a reset link if it can match the account.',
                        style: TextStyle(color: _textSecondary, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Username or email',
                        ),
                      ),
                      if (inlineError != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _InlineError(message: inlineError!),
                      ],
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: widget.controller.isAuthenticating
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: widget.controller.isAuthenticating
                        ? null
                        : () async {
                            final account = accountController.text.trim();
                            if (account.isEmpty) {
                              setDialogState(() {
                                inlineError = 'Enter your username or email.';
                              });
                              return;
                            }
                            final sent = await widget.controller
                                .requestPasswordReset(account);
                            if (sent && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          },
                    child: widget.controller.isAuthenticating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Send link'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      accountController.dispose();
    }
  }

  Future<void> _showQrLoginDialog() async {
    _qrAutoRequestedForVisibleMode = true;
    await widget.controller.prepareQrLoginChallenge();
    if (!mounted) {
      return;
    }
    final controller = widget.controller;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final challenge = controller.qrLoginChallenge;
            final canShowQr =
                challenge?.isUsable == true && !(challenge?.isExpired ?? true);
            final countdown = challenge?.secondsRemaining ?? 0;

            Widget buildQrSurface() {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: canShowQr
                        ? QrImageView(
                            data: challenge!.qrPayload,
                            version: QrVersions.auto,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF04111D),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF04111D),
                            ),
                          )
                        : controller.isPreparingQrLogin
                        ? const SizedBox.square(
                            dimension: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            Icons.qr_code_2_rounded,
                            size: 84,
                            color: _textMuted,
                          ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: _bgCard,
              title: const Text('Pair with QR code'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Open Account settings on a signed-in Android device, scan this code, and approve the login.',
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    buildQrSurface(),
                    const SizedBox(height: 14),
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: canShowQr
                          ? 'Refreshes in ${countdown}s'
                          : 'Waiting for code',
                    ),
                    if (controller.qrLoginErrorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineError(message: controller.qrLoginErrorMessage!),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: controller.isPreparingQrLogin
                      ? null
                      : () async {
                          _qrAutoRequestedForVisibleMode = true;
                          await widget.controller.prepareQrLoginChallenge(
                            force: true,
                          );
                          if (mounted) {
                            setDialogState(() {});
                          }
                        },
                  child: const Text('Refresh code'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _ensureQrLoginChallenge({bool force = false}) {
    if (!mounted) return;
    if (force) {
      _qrAutoRequestedForVisibleMode = true;
    }
    unawaited(widget.controller.prepareQrLoginChallenge(force: force));
  }

  Widget _buildAuthFormPane({
    required NeoAgentController controller,
    required List<AuthProviderCatalogItem> availableProviders,
    required bool awaitingTwoFactor,
    required bool showRegisterToggle,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Column(children: <Widget>[const _BrandLockup(logoSize: 58)]),
        const SizedBox(height: 26),
        Text(
          awaitingTwoFactor ? 'Verification' : title.toUpperCase(),
          style: _sectionEyebrowStyle(),
        ),
        const SizedBox(height: 8),
        Text(
          awaitingTwoFactor ? 'Enter 2FA code' : title,
          style: _displayTitleStyle(30),
        ),
        const SizedBox(height: 8),
        Text(
          awaitingTwoFactor
              ? 'Open your authenticator app and enter the current NeoOS code.'
              : subtitle,
          style: TextStyle(color: _textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.authInfoMessage != null) ...<Widget>[
          _InlineSuccess(message: controller.authInfoMessage!),
          const SizedBox(height: 24),
        ],
        if (awaitingTwoFactor) ...<Widget>[
          TextField(
            controller: _twoFactorController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '2FA or recovery code',
            ),
          ),
        ] else ...<Widget>[
          TextField(
            controller: _usernameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            onChanged: (_) => setState(() {}),
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (_registerMode) ...<Widget>[
            const SizedBox(height: 10),
            _PasswordStrengthIndicator(
              info: _passwordStrengthInfo(
                password: _passwordController.text,
                username: _usernameController.text,
                email: _emailController.text,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
          ],
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: controller.isAuthenticating
              ? null
              : () async {
                  if (awaitingTwoFactor) {
                    await controller.completeTwoFactorLogin(
                      code: _twoFactorController.text,
                    );
                    return;
                  }
                  if (_registerMode &&
                      _passwordController.text !=
                          _confirmPasswordController.text) {
                    widget.controller.showInlineError(
                      'Passwords do not match.',
                    );
                    return;
                  }
                  if (_registerMode) {
                    await controller.register(
                      username: _usernameController.text,
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                  } else {
                    await controller.login(
                      username: _usernameController.text,
                      password: _passwordController.text,
                    );
                  }
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
          child: controller.isAuthenticating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  awaitingTwoFactor
                      ? 'Verify'
                      : (_registerMode ? 'Create account' : 'Sign in'),
                ),
        ),
        if (awaitingTwoFactor) ...<Widget>[
          const SizedBox(height: 12),
          TextButton(
            onPressed: controller.isAuthenticating
                ? null
                : controller.cancelTwoFactorLogin,
            child: const Text('Back to sign in'),
          ),
        ] else ...<Widget>[
          if (availableProviders.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(child: Divider(color: _borderLight)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or continue with',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: _borderLight)),
              ],
            ),
            const SizedBox(height: 14),
            ...availableProviders.map(
              (provider) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: controller.isAuthenticating
                      ? null
                      : () => controller.authenticateWithProvider(
                          provider: provider.id,
                          register: _registerMode,
                        ),
                  icon: provider.icon == 'google'
                      ? const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4285F4),
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _registerMode
                        ? 'Register with ${provider.label}'
                        : 'Sign in with ${provider.label}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _bgPrimary.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ],
          if (!_registerMode && controller.serviceEmailConfigured) ...<Widget>[
            const SizedBox(height: 12),
            TextButton(
              onPressed: controller.isAuthenticating
                  ? null
                  : _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
            if (!showRegisterToggle) const SizedBox(height: 12),
          ],
          if (showRegisterToggle) ...<Widget>[
            const SizedBox(height: 12),
            TextButton(
              onPressed: controller.isAuthenticating
                  ? null
                  : () {
                      setState(() {
                        _registerMode = !_registerMode;
                      });
                      if (!_registerMode) {
                        _qrAutoRequestedForVisibleMode = false;
                        _ensureQrLoginChallenge(force: true);
                      }
                    },
              child: Text(
                _registerMode
                    ? 'Already have an account? Sign in'
                    : 'Need a new account? Register',
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildQrLoginPane(NeoAgentController controller) {
    final challenge = controller.qrLoginChallenge;
    final countdown = challenge?.secondsRemaining ?? 0;
    final canShowQr =
        challenge?.isUsable == true && !(challenge?.isExpired ?? true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final narrow = constraints.maxWidth < 520;
        final showInlineQr = !narrow;
        final panelPadding = compact ? 18.0 : 24.0;
        final qrShellPadding = compact ? 14.0 : 18.0;
        final qrCardPadding = compact ? 14.0 : 18.0;
        final titleSize = compact ? 22.0 : 28.0;
        final titleAlignment = compact ? TextAlign.center : TextAlign.left;
        final contentAlignment = compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;

        Widget buildInfoSection() {
          return _InfoChip(
            icon: Icons.timer_outlined,
            label: canShowQr
                ? 'Refreshes in ${countdown}s'
                : 'Waiting for code',
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF0A1D2E),
                _bgSecondary.withValues(alpha: 0.96),
                const Color(0xFF112B43),
              ],
            ),
            border: Border.all(color: _borderLight.withValues(alpha: 0.45)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF6EDBFF).withValues(alpha: 0.12),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: compact ? -18 : -24,
                right: compact ? -24 : -12,
                child: IgnorePointer(
                  child: Container(
                    width: compact ? 86 : 120,
                    height: compact ? 86 : 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6EDBFF).withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: compact ? -34 : -36,
                left: compact ? -28 : -18,
                child: IgnorePointer(
                  child: Container(
                    width: compact ? 110 : 140,
                    height: compact ? 110 : 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF58E0A2).withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(panelPadding),
                child: Column(
                  crossAxisAlignment: contentAlignment,
                  children: <Widget>[
                    Text(
                      'Scan with NeoOS on your phone',
                      textAlign: titleAlignment,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: compact ? -0.3 : -0.6,
                        color: Colors.white,
                        height: compact ? 1.05 : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        'On a signed-in Android device, open Account settings, scan this code, and approve the login.',
                        textAlign: titleAlignment,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 22),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(qrShellPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(compact ? 20 : 24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          if (showInlineQr)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(qrCardPadding),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  compact ? 18 : 22,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Center(
                                  child: canShowQr
                                      ? QrImageView(
                                          data: challenge!.qrPayload,
                                          version: QrVersions.auto,
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: Color(0xFF04111D),
                                          ),
                                          dataModuleStyle:
                                              const QrDataModuleStyle(
                                                dataModuleShape:
                                                    QrDataModuleShape.square,
                                                color: Color(0xFF04111D),
                                              ),
                                        )
                                      : controller.isPreparingQrLogin
                                      ? const SizedBox.square(
                                          dimension: 40,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          Icons.qr_code_2_rounded,
                                          size: narrow ? 72 : 84,
                                          color: _textMuted,
                                        ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: controller.isPreparingQrLogin
                                    ? null
                                    : _showQrLoginDialog,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF04111D),
                                ),
                                icon: controller.isPreparingQrLogin
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF04111D),
                                        ),
                                      )
                                    : const Icon(Icons.qr_code_2_rounded),
                                label: Text(
                                  canShowQr
                                      ? 'Show QR code'
                                      : 'Prepare QR code',
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          buildInfoSection(),
                        ],
                      ),
                    ),
                    if (controller.qrLoginErrorMessage != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _InlineError(message: controller.qrLoginErrorMessage!),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Approval stays inside your authenticated mobile session, and each code expires automatically after a short window.',
                      textAlign: titleAlignment,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: controller.isPreparingQrLogin
                            ? null
                            : () => _ensureQrLoginChallenge(force: true),
                        icon: controller.isPreparingQrLogin
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh code'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableProviders = controller.authProviders
        .where((provider) => provider.configured)
        .toList();
    if (!controller.hasUser) {
      _registerMode = true;
    }

    final title = _registerMode
        ? (controller.hasUser ? 'Create account' : 'Create the first account')
        : 'Sign in';
    final subtitle = _registerMode
        ? (controller.hasUser
              ? 'Create another NeoOS account.'
              : 'This account will unlock NeoOS on this machine.')
        : 'Enter your NeoOS account details.';
    final awaitingTwoFactor = controller.isAwaitingTwoFactor;
    final showRegisterToggle =
        controller.registrationOpen && controller.hasUser;
    final showQrLogin = !awaitingTwoFactor && !_registerMode;

    if (showQrLogin &&
        !controller.isPreparingQrLogin &&
        !controller.isAuthenticated &&
        !_qrAutoRequestedForVisibleMode) {
      _qrAutoRequestedForVisibleMode = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureQrLoginChallenge();
      });
    }
    if (!showQrLogin) {
      _qrAutoRequestedForVisibleMode = false;
    }

    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      viewportConstraints.maxWidth < 480 ? 14 : 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: showQrLogin ? 980 : 468,
                        ),
                        child: _EntranceMotion(
                          child: _GlassSurface(
                            borderRadius: BorderRadius.circular(32),
                            blurSigma: 28,
                            boxShadow: _softPanelShadow,
                            overlayGradient: _panelGradient,
                            fillColor: _glassFill,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                viewportConstraints.maxWidth < 480 ? 18 : 34,
                                viewportConstraints.maxWidth < 480 ? 20 : 30,
                                viewportConstraints.maxWidth < 480 ? 18 : 34,
                                viewportConstraints.maxWidth < 480 ? 20 : 30,
                              ),
                              child: LayoutBuilder(
                                builder: (context, panelConstraints) {
                                  final useWideQrLayout =
                                      showQrLogin &&
                                      panelConstraints.maxWidth >= 820;
                                  final formPane = _buildAuthFormPane(
                                    controller: controller,
                                    availableProviders: availableProviders,
                                    awaitingTwoFactor: awaitingTwoFactor,
                                    showRegisterToggle: showRegisterToggle,
                                    title: title,
                                    subtitle: subtitle,
                                  );
                                  if (!showQrLogin) {
                                    return formPane;
                                  }
                                  if (useWideQrLayout) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(flex: 11, child: formPane),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 10,
                                          child: _buildQrLoginPane(controller),
                                        ),
                                      ],
                                    );
                                  }
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      formPane,
                                      const SizedBox(height: 22),
                                      _buildQrLoginPane(controller),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _blockedDialogOpen = false;
  SidebarGroup? _expandedSidebarGroup;
  AppSection? _lastSelectedSection;

  @override
  void initState() {
    super.initState();

    // Initialize Proactive Context Features for mobile
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final backendUrl = widget.controller.backendUrl;
      final sessionCookie = widget.controller.sessionCookie?.trim() ?? '';
      final canInitializeMobileAutomation =
          backendUrl.trim().isNotEmpty && sessionCookie.isNotEmpty;

      if (canInitializeMobileAutomation) {
        final locationService = LocationService();

        locationService
            .initialize(context)
            .then((_) {
              if (mounted) {
                locationService.startGeofenceTracking(
                  backendUrl,
                  sessionCookie,
                );
              }
            })
            .catchError((error) {
              if (mounted) {
                debugPrint('LocationService initialization failed: $error');
              }
            });

        if (Platform.isAndroid) {
          NotificationInterceptor().initialize(
            context,
            backendUrl,
            sessionCookie,
          );
        }
      }
    }

    _lastSelectedSection = widget.controller.selectedSection;
    _expandedSidebarGroup = _sidebarGroupForSection(
      widget.controller.selectedSection,
    );
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastSelectedSection = widget.controller.selectedSection;
      _expandedSidebarGroup = _sidebarGroupForSection(
        widget.controller.selectedSection,
      );
    }
  }

  SidebarGroup? _sidebarGroupForSection(AppSection section) {
    if (!_mainSections(widget.controller).contains(section)) {
      return null;
    }
    return section.group;
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final nextSection = widget.controller.selectedSection;
    setState(() {
      if (_lastSelectedSection != nextSection) {
        final oldGroup = _lastSelectedSection == null
            ? null
            : _sidebarGroupForSection(_lastSelectedSection!);
        final nextGroup = _sidebarGroupForSection(nextSection);
        if (oldGroup != nextGroup) {
          _expandedSidebarGroup = nextGroup;
        }
        _lastSelectedSection = nextSection;
      }
    });
  }

  void _toggleSidebarGroup(SidebarGroup group) {
    setState(() {
      _expandedSidebarGroup = _expandedSidebarGroup == group ? null : group;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pendingBlockedSender = controller.pendingBlockedSenderNotice;

    if (!_blockedDialogOpen && pendingBlockedSender != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _blockedDialogOpen) {
          return;
        }
        _showBlockedSenderDialog(pendingBlockedSender);
      });
    }

    final wide = MediaQuery.sizeOf(context).width >= 1080;

    if (wide) {
      return _AmbientBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  _Sidebar(
                    controller: controller,
                    expandedGroup: _expandedSidebarGroup,
                    onToggleGroup: _toggleSidebarGroup,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _GlassSurface(
                      borderRadius: BorderRadius.circular(32),
                      blurSigma: 28,
                      boxShadow: _softPanelShadow,
                      overlayGradient: _panelGradient,
                      fillColor: _glassFill,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0.015, 0.02),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<AppSection>(
                              controller.selectedSection,
                            ),
                            child: _SectionBody(controller: controller),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: _MobileDrawer(
          controller: controller,
          expandedGroup: _expandedSidebarGroup,
          onToggleGroup: _toggleSidebarGroup,
        ),
        appBar: AppBar(
          title: Text(controller.selectedSection.navigationTitle),
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _GlassSurface(
              borderRadius: BorderRadius.circular(26),
              blurSigma: 24,
              boxShadow: _softPanelShadow,
              overlayGradient: _panelGradient,
              fillColor: _glassFill,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<AppSection>(controller.selectedSection),
                    child: _SectionBody(controller: controller),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBlockedSenderDialog(BlockedSenderNotice notice) async {
    _blockedDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _bgCard,
            title: Text('Allow sender on ${notice.platform.toUpperCase()}?'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notice.senderLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (notice.meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        notice.meta,
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'This sender is currently blocked by the access list. You can allow them now or jump to Messaging to edit the full list.',
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                    if (notice.suggestions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      ...notice.suggestions.map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await widget.controller
                                    .allowMessagingSuggestion(
                                      notice.platform,
                                      suggestion,
                                    );
                              },
                              icon: Icon(Icons.verified_user_outlined),
                              label: Text(suggestion.label),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  widget.controller.setSelectedSection(AppSection.messaging);
                  Navigator.of(dialogContext).pop();
                },
                child: Text('Open Messaging'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Dismiss'),
              ),
            ],
          );
        },
      );
    } finally {
      widget.controller.consumeBlockedSenderNotice(notice.id);
      if (mounted) {
        setState(() => _blockedDialogOpen = false);
      } else {
        _blockedDialogOpen = false;
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.controller,
    required this.expandedGroup,
    required this.onToggleGroup,
  });

  final NeoAgentController controller;
  final SidebarGroup? expandedGroup;
  final ValueChanged<SidebarGroup> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      width: 254,
      borderRadius: BorderRadius.circular(30),
      blurSigma: 26,
      boxShadow: _softPanelShadow,
      fillColor: _bgSecondary.withValues(alpha: 0.34),
      overlayGradient: LinearGradient(
        colors: <Color>[
          _bgSecondary.withValues(alpha: 0.96),
          _bgTertiary.withValues(alpha: 0.88),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: const _BrandLockup(
                        logoSize: 34,
                        titleFontSize: 18,
                        direction: Axis.horizontal,
                        spacing: 12,
                        alignment: CrossAxisAlignment.start,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controller.agentProfiles.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: _AgentSwitcher(controller: controller),
            ),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _buildSidebarItems(
                controller,
                onSelect: controller.setSelectedSection,
                expandedGroup: expandedGroup,
                onToggleGroup: onToggleGroup,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        controller.accountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ProfileSettingsButton(
                      controller: controller,
                      onTap: () => controller.setSelectedSection(
                        AppSection.accountSettings,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SidebarIconButton(
                      tooltip: 'Logout',
                      icon: Icons.logout,
                      onTap: controller.logout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentSwitcher extends StatelessWidget {
  const _AgentSwitcher({required this.controller, this.onChanged});

  final NeoAgentController controller;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: controller.selectedAgentId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Agent',
        prefixIcon: Icon(Icons.smart_toy_outlined, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      items: controller.agentProfiles
          .map(
            (agent) => DropdownMenuItem<String>(
              value: agent.id,
              child: Text(agent.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        onChanged?.call();
        unawaited(controller.switchAgent(value));
      },
    );
  }
}

class _ProfileSettingsButton extends StatelessWidget {
  const _ProfileSettingsButton({required this.controller, required this.onTap});

  final NeoAgentController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = controller.accountLabel.trim();
    final initial = label.isEmpty ? 'N' : label.characters.first.toUpperCase();
    final active = controller.selectedSection == AppSection.accountSettings;
    return Tooltip(
      message: 'Account settings',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? _accentMuted : _bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: active ? _accent : _borderLight),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: active ? _accentHover : _textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? _accent : _borderLight),
                ),
                child: Icon(
                  Icons.settings,
                  size: 11,
                  color: active ? _accentHover : _textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.controller,
    required this.expandedGroup,
    required this.onToggleGroup,
  });

  final NeoAgentController controller;
  final SidebarGroup? expandedGroup;
  final ValueChanged<SidebarGroup> onToggleGroup;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _bgSecondary,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: const _BrandLockup(
                          logoSize: 30,
                          titleFontSize: 18,
                          direction: Axis.horizontal,
                          spacing: 10,
                          alignment: CrossAxisAlignment.start,
                        ),
                      ),
                    ],
                  ),
                  if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _AgentSwitcher(
                      controller: controller,
                      onChanged: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _buildSidebarItems(
                  controller,
                  onSelect: (section) {
                    controller.setSelectedSection(section);
                    Navigator.of(context).pop();
                  },
                  expandedGroup: expandedGroup,
                  onToggleGroup: onToggleGroup,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  _ProfileSettingsButton(
                    controller: controller,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.setSelectedSection(AppSection.accountSettings);
                    },
                  ),
                  const SizedBox(width: 8),
                  _SidebarIconButton(
                    tooltip: 'Logout',
                    icon: Icons.logout,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.selectedSection) {
      case AppSection.chat:
        return ChatPanel(controller: controller);
      case AppSection.voiceAssistant:
        return VoiceAssistantPanel(controller: controller);
      case AppSection.devices:
        return DevicesPanel(controller: controller);
      case AppSection.recordings:
        return RecordingsPanel(controller: controller);
      case AppSection.messaging:
        return MessagingPanel(controller: controller);
      case AppSection.runs:
        return RunsPanel(controller: controller);
      case AppSection.settings:
        return SettingsPanel(controller: controller);
      case AppSection.accountSettings:
        return AccountSettingsPanel(controller: controller);
      case AppSection.logs:
        return LogsPanel(controller: controller);
      case AppSection.skills:
        return SkillsPanel(controller: controller);
      case AppSection.agents:
        return AgentsPanel(controller: controller);
      case AppSection.integrations:
        return IntegrationsPanel(controller: controller);
      case AppSection.memory:
        return MemoryPanel(controller: controller);
      case AppSection.tasks:
        return TasksPanel(controller: controller);
      case AppSection.widgets:
        return WidgetsPanel(controller: controller);
      case AppSection.mcp:
        return McpPanel(controller: controller);
      case AppSection.health:
        return controller.showHealthSection
            ? HealthPanel(controller: controller)
            : ChatPanel(controller: controller);
    }
  }
}
