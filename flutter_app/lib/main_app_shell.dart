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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _BrandLockup(logoSize: 52),
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(minHeight: 4),
                ),
              ),
              const SizedBox(height: 14),
              Text(appStrings.loadingNeoagent),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.controller, this.runtimeManager});

  final NeoAgentController controller;
  final LocalRuntimeManager? runtimeManager;

  @override
  State<AuthView> createState() => _AuthViewState();
}

// Mirrors the server rule in server/services/account/email.js, so the form
// rejects exactly what registration would reject rather than guessing.
final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool _looksLikeEmail(String value) {
  final email = value.trim().toLowerCase();
  return email.length <= 320 &&
      _emailShape.hasMatch(email) &&
      !email.contains('..');
}

class _AuthViewState extends State<AuthView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _twoFactorController;
  bool _registerMode = false;
  bool _qrAutoRequestedForVisibleMode = false;
  LocalRuntimeStatus? _localRuntimeStatus;

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
    unawaited(_refreshLocalRuntimeStatus());
  }

  Future<void> _refreshLocalRuntimeStatus() async {
    if (!_supportsDesktopShell) return;
    try {
      final status = await (widget.runtimeManager ?? LocalRuntimeManager())
          .inspect();
      if (!mounted) return;
      setState(() => _localRuntimeStatus = status);
    } on Object {
      // No readable runtime on this computer simply means no shortcut.
    }
  }

  /// Whether this computer hosts the server this window signs in to.
  ///
  /// The status comes from the local runtime CLI and the address has to be the
  /// loopback one already selected, so a remote NeoAgent server never surfaces
  /// the shortcut — there would be nothing here for it to repair.
  bool get _showsLocalServerRepair {
    final status = _localRuntimeStatus;
    return _supportsDesktopShell &&
        status?.installed == true &&
        widget.controller.isLocalRuntimeBackend(status?.backendUrl);
  }

  Future<void> _openLocalServerSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: ServerPanel(controller: widget.controller),
        ),
      ),
    );
    if (!mounted) return;
    await _refreshLocalRuntimeStatus();
    if (!mounted) return;
    // Signing in can only work once the server answers again.
    if (_localRuntimeStatus?.running == true &&
        !widget.controller.isAuthenticated) {
      await widget.controller.bootstrap();
    }
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
                title: Text(appStrings.resetPassword),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        appStrings.enterYourUsernameOrAccountEmail,
                        style: TextStyle(color: _textSecondary, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: appStrings.usernameOrEmail,
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
                    child: Text(appStrings.cancel),
                  ),
                  FilledButton(
                    onPressed: widget.controller.isAuthenticating
                        ? null
                        : () async {
                            final account = accountController.text.trim();
                            if (account.isEmpty) {
                              setDialogState(() {
                                inlineError = appStrings.enterYourUsernameOrEmail;
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
                        : Text(appStrings.sendLink),
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
                              color: _qrDarkColor,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _qrDarkColor,
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
              title: Text(appStrings.pairWithQrCode),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      appStrings.openAccountSettingsOnASigned,
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    buildQrSurface(),
                    const SizedBox(height: 14),
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: canShowQr
                          ? appStrings.refreshesInArg1S(countdown)
                          : appStrings.waitingForCode,
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
                  child: Text(appStrings.refreshCode),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(appStrings.close),
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
    final showSecurityKeySignIn =
        !_registerMode && controller.supportsSecurityKeys;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Column(children: <Widget>[const _BrandLockup(logoSize: 58)]),
        const SizedBox(height: 26),
        Text(
          awaitingTwoFactor ? appStrings.verification : title.toUpperCase(),
          style: _sectionEyebrowStyle(),
        ),
        const SizedBox(height: 8),
        Text(
          awaitingTwoFactor ? appStrings.enter2faCode : title,
          style: _displayTitleStyle(30),
        ),
        const SizedBox(height: 8),
        Text(
          awaitingTwoFactor
              ? appStrings.openYourAuthenticatorAppAndEnterThe
              : subtitle,
          style: TextStyle(color: _textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(
            message: controller.errorMessage!,
            onDismiss: controller.clearInlineError,
          ),
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
            decoration: InputDecoration(
              labelText: appStrings.n2faOrRecoveryCode,
            ),
          ),
        ] else ...<Widget>[
          TextField(
            controller: _usernameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: appStrings.username),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            onChanged: (_) => setState(() {}),
            obscureText: true,
            decoration: InputDecoration(labelText: appStrings.password),
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
              decoration: InputDecoration(labelText: appStrings.email),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: appStrings.confirmPassword2),
            ),
          ],
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: controller.isAuthenticating
              ? null
              : () async {
                  if (awaitingTwoFactor) {
                    final code = _twoFactorController.text.trim();
                    if (code.isEmpty) {
                      widget.controller.showInlineError(
                        appStrings.enterYour2faOrRecoveryCode,
                      );
                      return;
                    }
                    await controller.completeTwoFactorLogin(code: code);
                    return;
                  }
                  final username = _usernameController.text.trim();
                  final password = _passwordController.text;
                  if (username.isEmpty) {
                    widget.controller.showInlineError(appStrings.enterAUsername);
                    return;
                  }
                  if (password.isEmpty) {
                    widget.controller.showInlineError(appStrings.enterAPassword);
                    return;
                  }
                  if (_registerMode) {
                    final email = _emailController.text.trim();
                    if (email.isEmpty || !_looksLikeEmail(email)) {
                      widget.controller.showInlineError(
                        appStrings.enterAValidEmailAddress,
                      );
                      return;
                    }
                    if (password != _confirmPasswordController.text) {
                      widget.controller.showInlineError(
                        appStrings.passwordsDoNotMatch,
                      );
                      return;
                    }
                    await controller.register(
                      username: username,
                      email: email,
                      password: password,
                    );
                  } else {
                    await controller.login(
                      username: username,
                      password: password,
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
                      : (_registerMode ? 'Create account' : appStrings.signIn),
                ),
        ),
        if (awaitingTwoFactor) ...<Widget>[
          const SizedBox(height: 12),
          TextButton(
            onPressed: controller.isAuthenticating
                ? null
                : controller.cancelTwoFactorLogin,
            child: Text(appStrings.backToSignIn),
          ),
        ] else ...<Widget>[
          if (availableProviders.isNotEmpty ||
              showSecurityKeySignIn) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(child: Divider(color: _borderLight)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    appStrings.orContinueWith,
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
                      ? Text(
                          'G',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            // Google brand blue — required by Google Sign-In
                            // branding guidelines, not a palette deviation.
                            color: Color(0xFF4285F4),
                          ),
                        )
                      : Icon(Icons.link),
                  label: Text(
                    _registerMode
                        ? appStrings.registerWithArg1(provider.label)
                        : appStrings.signInWithArg1(provider.label),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _bgPrimary.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
            if (showSecurityKeySignIn)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: controller.isAuthenticating
                      ? null
                      : () => controller.signInWithSecurityKey(
                          username: _usernameController.text,
                        ),
                  icon: Icon(Icons.key),
                  label: Text(appStrings.signInWithASecurityKey),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _bgPrimary.withValues(alpha: 0.18),
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
              child: Text(appStrings.forgotPassword),
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
                    ? appStrings.alreadyHaveAnAccountSignIn
                    : appStrings.needANewAccountRegister,
              ),
            ),
          ],
        ],
        if (_showsLocalServerRepair) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openLocalServerSettings,
            icon: Icon(Icons.dns_outlined, size: 18),
            label: Text(
              _localRuntimeStatus?.running == true
                  ? appStrings.serverOnThisComputer
                  : appStrings.theServerOnThisComputerIs,
            ),
          ),
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
        final isLight = Theme.of(context).brightness == Brightness.light;
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
                ? appStrings.refreshesInArg1S(countdown)
                : appStrings.waitingForCode,
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(_bgCard, _accentAlt, isLight ? 0.05 : 0.11)!,
                _bgSecondary.withValues(alpha: isLight ? 0.92 : 0.96),
                Color.lerp(_bgCard, _accent, isLight ? 0.04 : 0.08)!,
              ],
            ),
            border: Border.all(color: _borderLight.withValues(alpha: 0.45)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _accent.withValues(alpha: isLight ? 0.08 : 0.12),
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
                      color: _accent.withValues(alpha: isLight ? 0.07 : 0.12),
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
                      color: _accentAlt.withValues(
                        alpha: isLight ? 0.06 : 0.10,
                      ),
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
                      appStrings.scanWithNeoagentOnYourPhone,
                      textAlign: titleAlignment,
                      style: GoogleFonts.geist(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: compact ? -0.3 : -0.6,
                        color: _textPrimary,
                        height: compact ? 1.05 : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        appStrings.onASignedInAndroidDevice,
                        textAlign: titleAlignment,
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 22),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(qrShellPadding),
                      decoration: BoxDecoration(
                        color: _bgCard.withValues(alpha: isLight ? 0.72 : 0.48),
                        borderRadius: BorderRadius.circular(compact ? 20 : 24),
                        border: Border.all(color: _borderLight),
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
                                            color: _qrDarkColor,
                                          ),
                                          dataModuleStyle:
                                              const QrDataModuleStyle(
                                                dataModuleShape:
                                                    QrDataModuleShape.square,
                                                color: _qrDarkColor,
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
                                  foregroundColor: _qrDarkColor,
                                ),
                                icon: controller.isPreparingQrLogin
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _qrDarkColor,
                                        ),
                                      )
                                    : Icon(Icons.qr_code_2_rounded),
                                label: Text(
                                  canShowQr
                                      ? appStrings.showQrCode
                                      : appStrings.prepareQrCode,
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
                      appStrings.approvalStaysInsideYourAuthenticatedMobile,
                      textAlign: titleAlignment,
                      style: TextStyle(color: _textSecondary, height: 1.45),
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
                            : Icon(Icons.refresh_rounded),
                        label: Text(appStrings.refreshCode),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: _textPrimary,
                          side: BorderSide(color: _borderLight),
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
        ? (controller.hasUser ? 'Create account' : appStrings.createTheFirstAccount)
        : appStrings.signIn;
    final subtitle = _registerMode
        ? (controller.hasUser
              ? appStrings.createAnotherNeoagentAccount
              : appStrings.thisAccountWillUnlockNeoagentOn)
        : appStrings.enterYourNeoagentAccountDetails;
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

    return _ControlSurfaceBackdrop(
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
                      viewportConstraints.maxWidth < AppBreakpoints.mobile
                          ? 14
                          : 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: showQrLogin ? 980 : 468,
                        ),
                        child: _EntranceMotion(
                          child: _PanelSurface(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: _softPanelShadow,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                viewportConstraints.maxWidth <
                                        AppBreakpoints.mobile
                                    ? 18
                                    : 34,
                                viewportConstraints.maxWidth <
                                        AppBreakpoints.mobile
                                    ? 20
                                    : 30,
                                viewportConstraints.maxWidth <
                                        AppBreakpoints.mobile
                                    ? 18
                                    : 34,
                                viewportConstraints.maxWidth <
                                        AppBreakpoints.mobile
                                    ? 20
                                    : 30,
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
  bool _approvalSheetOpen = false;
  bool _callPermissionsAsked = false;
  SidebarGroup? _expandedSidebarGroup;
  AppSection? _lastSelectedSection;
  final GlobalKey _devicesPanelKey = GlobalKey();

  /// What the phone triggers were last set to, so a settings change starts or
  /// stops each one exactly once.
  bool? _locationTriggersRunning;
  bool? _notificationTriggersRunning;

  @override
  void initState() {
    super.initState();
    _syncPhoneTriggers();
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
    final visibleSection = section.canonicalSection;
    if (!_mainSections(widget.controller).contains(visibleSection)) {
      return null;
    }
    return visibleSection.group;
  }

  /// Starts or stops the phone's location and notification triggers to match
  /// Settings › General.
  void _syncPhoneTriggers() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final controller = widget.controller;
    final backendUrl = controller.backendUrl;
    final sessionCookie = controller.sessionCookie?.trim() ?? '';
    if (backendUrl.trim().isEmpty || sessionCookie.isEmpty) return;

    final location = controller.locationTriggersEnabled;
    if (location != _locationTriggersRunning) {
      _locationTriggersRunning = location;
      final locationService = LocationService();
      if (location) {
        locationService
            .initialize(context)
            .then((_) {
              if (mounted && controller.locationTriggersEnabled) {
                locationService.startGeofenceTracking(
                  controller.backendClient,
                  backendUrl,
                );
              }
            })
            .catchError((error) {
              if (mounted) {
                debugPrint(
                  appStrings.locationserviceInitializationFailedArg1(error),
                );
              }
            });
      } else {
        locationService.stopGeofenceTracking();
      }
    }

    final notifications =
        Platform.isAndroid && controller.notificationTriggersEnabled;
    if (notifications != _notificationTriggersRunning) {
      _notificationTriggersRunning = notifications;
      if (notifications) {
        NotificationInterceptor().initialize(backendUrl, sessionCookie);
      } else {
        NotificationInterceptor().stop();
      }
    }
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _syncPhoneTriggers();
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

  Widget _withIncomingCall(Widget child) {
    final call = widget.controller.incomingAgentCall;
    if (call == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        AgentCallScreen(
          key: const Key('incoming-agent-call'),
          controller: widget.controller,
        ),
      ],
    );
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
    // Wait until no call is ringing or live, so the sheet never covers it.
    final inCall = controller.incomingAgentCall != null ||
        controller.voiceAssistantLiveState.sessionId.isNotEmpty;
    if (!_callPermissionsAsked && controller.isAuthenticated && !inCall) {
      _callPermissionsAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(promptForCallPermissionsIfNeeded(context));
      });
    }
    final pendingApproval = controller.pendingApproval;
    if (!_approvalSheetOpen && pendingApproval != null) {
      _approvalSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: false,
          enableDrag: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => ToolApprovalSheet(
            request: pendingApproval,
            controller: controller,
          ),
        ).whenComplete(() {
          if (mounted) setState(() => _approvalSheetOpen = false);
        });
      });
    }

    final wide = MediaQuery.sizeOf(context).width >= 1080;

    if (wide) {
      return _withIncomingCall(
        _ControlSurfaceBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: <Widget>[
                _Sidebar(
                  controller: controller,
                  expandedGroup: _expandedSidebarGroup,
                  onToggleGroup: _toggleSidebarGroup,
                ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0.018, 0.026),
                          end: Offset.zero,
                        ).animate(animation);
                        final scale = Tween<double>(
                          begin: 0.992,
                          end: 1,
                        ).animate(animation);
                        return ScaleTransition(
                          scale: scale,
                          alignment: Alignment.topCenter,
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<AppSection>(controller.selectedSection),
                        child: _SectionBody(
                          controller: controller,
                          devicesPanelKey: _devicesPanelKey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // On a phone the voice call takes the whole screen, like a phone call.
    if (controller.selectedSection == AppSection.voiceAssistant &&
        MediaQuery.sizeOf(context).shortestSide < 600) {
      return _withIncomingCall(
        _ControlSurfaceBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AgentCallScreen(controller: controller),
          ),
        ),
      );
    }

    // Phones: a four-tab bottom bar over the same four sidebar groups, in
    // place of the app bar and hamburger drawer. Sections inside a group stay
    // one tap away via the chip row, so nothing the drawer reached is lost.
    final group = _sidebarGroupForSection(controller.selectedSection);
    final groupSections = group == null
        ? const <AppSection>[]
        : _groupSections(controller, group);

    return _withIncomingCall(
      _ControlSurfaceBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _MobileTopBar(controller: controller),
                if (groupSections.length > 1)
                  _MobileSectionChips(
                    sections: groupSections,
                    selected: controller.selectedSection.canonicalSection,
                    onSelect: controller.setSelectedSection,
                  ),
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.014),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<AppSection>(controller.selectedSection),
                        child: _SectionBody(
                          controller: controller,
                          devicesPanelKey: _devicesPanelKey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _MobileTabBar(
            controller: controller,
            selected: group,
            onSelect: (nextGroup) {
              _expandedSidebarGroup = nextGroup;
              controller.setSelectedSection(
                _groupDefaultSection(controller, nextGroup),
              );
            },
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            title: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.shield_outlined, color: _accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        appStrings.messageNeedsAccess,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notice.platform.toUpperCase(),
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderLight),
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: _accent.withValues(alpha: 0.12),
                            foregroundColor: _accent,
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
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
                                  const SizedBox(height: 3),
                                  Text(
                                    notice.meta,
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appStrings.chooseWhereThisPersonShouldBe(widget.controller.activeAgentLabel),
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                    if (notice.suggestions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      ...notice.suggestions.map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BlockedAccessChoice(
                            suggestion: suggestion,
                            agentName: widget.controller.activeAgentLabel,
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await widget.controller.allowMessagingSuggestion(
                                notice.platform,
                                suggestion,
                                chatId: notice.chatId,
                              );
                            },
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
                  widget.controller.openSettings(SettingsPage.messaging);
                  Navigator.of(dialogContext).pop();
                },
                child: Text(appStrings.whoCanMessage),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await widget.controller.ignoreBlockedSender(notice);
                },
                child: Text(appStrings.ignoreThisChat),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(appStrings.notNow),
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

class _BlockedAccessChoice extends StatelessWidget {
  const _BlockedAccessChoice({
    required this.suggestion,
    required this.onPressed,
    required this.agentName,
  });

  final QuickAllowSuggestion suggestion;
  final VoidCallback onPressed;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final (icon, title, description) = switch (suggestion.bucket) {
      'sharedMemberRules' => (
        Icons.person_pin_circle_outlined,
        appStrings.onlyInThisGroup,
        appStrings.letThisPersonTalkToArg1(agentName),
      ),
      'sharedActorRules' => (
        Icons.person_add_alt_1_rounded,
        appStrings.thisPersonAnywhere,
        appStrings.letThisPersonTalkToArg12(agentName),
      ),
      'sharedSpaceRules' => (
        Icons.groups_2_outlined,
        appStrings.everyoneInThisGroup,
        appStrings.letEveryoneInThisGroupTalk(agentName),
      ),
      _ => (
        Icons.person_outline_rounded,
        appStrings.privateChatsOnly,
        appStrings.letThisPersonSendArg1A(agentName),
      ),
    };
    return Material(
      color: _bgSecondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderLight),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: _textMuted),
            ],
          ),
        ),
      ),
    );
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
    return Container(
      width: 276,
      decoration: BoxDecoration(
        color: _bgSecondary,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                color: _bgTertiary,
              ),
              child: Row(
                children: <Widget>[
                  _LiveMascot(controller: controller, size: 38),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'NeoAgent',
                          style: GoogleFonts.geist(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appStrings.controlSurface,
                          style: GoogleFonts.geistMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (controller.agentProfiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: _AgentSwitcher(controller: controller),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              children: _buildSidebarItems(
                controller,
                onSelect: controller.setSelectedSection,
                expandedGroup: expandedGroup,
                onToggleGroup: onToggleGroup,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _SidebarSettingsButton(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _AgentSwitcher extends StatefulWidget {
  const _AgentSwitcher({required this.controller, this.compact = false});

  final NeoAgentController controller;

  /// Phone header treatment: a single-line pill — glyph, name, chevron. Drops
  /// the DEFAULT tag and the description line, which cost a lot of vertical
  /// room for something you read once.
  final bool compact;

  @override
  State<_AgentSwitcher> createState() => _AgentSwitcherState();
}

class _AgentSwitcherState extends State<_AgentSwitcher> {
  final MenuController _menuController = MenuController();

  void _toggleMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
    setState(() {});
  }

  Future<void> _selectAgent(String agentId) async {
    if (widget.controller.selectedAgentId == agentId) {
      _menuController.close();
      setState(() {});
      return;
    }
    _menuController.close();
    setState(() {});
    await widget.controller.switchAgent(agentId);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selectedAgent =
        controller.activeAgent ?? controller.agentProfiles.first;
    final isMenuOpen = _menuController.isOpen;

    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      crossAxisUnconstrained: false,
      onOpen: () => setState(() {}),
      onClose: () => setState(() {}),
      menuChildren: <Widget>[
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: _softPanelShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controller.agentProfiles
                    .map(
                      (agent) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: _AgentSwitcherMenuItem(
                          agent: agent,
                          selected: agent.id == controller.selectedAgentId,
                          onTap: () => _selectAgent(agent.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
      builder: (context, menuController, child) {
        return Material(
          color: Colors.transparent,
          child: Tooltip(
            message: appStrings.switchAgent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _toggleMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: widget.compact
                    ? const EdgeInsets.fromLTRB(6, 5, 8, 5)
                    : const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    widget.compact ? 999 : 14,
                  ),
                  color: _bgCard,
                  border: Border.all(
                    color: isMenuOpen
                        ? _accent.withValues(alpha: 0.45)
                        : _borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: widget.compact
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  children: <Widget>[
                    _AgentGlyph(
                      agent: selectedAgent,
                      selected: true,
                      compact: true,
                    ),
                    SizedBox(width: widget.compact ? 7 : 10),
                    if (widget.compact)
                      Flexible(
                        child: Text(
                          selectedAgent.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    selectedAgent.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                ),
                                if (selectedAgent.isDefault) ...<Widget>[
                                  const SizedBox(width: 8),
                                  _AgentTag(
                                    label: appStrings.default3,
                                    color: _accent,
                                    foreground: _accentHover,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _agentSwitcherSubtitle(selectedAgent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: widget.compact ? 3 : 8),
                    AnimatedRotation(
                      turns: isMenuOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: widget.compact ? 17 : 20,
                        color: isMenuOpen ? _accentHover : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _agentSwitcherSubtitle(AgentProfile agent) {
  if (agent.description.trim().isNotEmpty) {
    return agent.description.trim();
  }
  if (agent.responsibilities.trim().isNotEmpty) {
    return agent.responsibilities.trim();
  }
  return agent.canDelegate
      ? appStrings.canCoordinateDelegatedWork
      : appStrings.focusedExecutionProfile;
}

class _AgentSwitcherMenuItem extends StatelessWidget {
  const _AgentSwitcherMenuItem({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final AgentProfile agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: agent.displayName,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected ? _accent.withValues(alpha: 0.10) : _bgSecondary,
              border: Border.all(
                color: selected
                    ? _accent.withValues(alpha: 0.55)
                    : _borderLight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _AgentGlyph(agent: agent, selected: selected, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                agent.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (agent.isDefault) ...<Widget>[
                              const SizedBox(width: 8),
                              _AgentTag(
                                label: appStrings.default3,
                                color: _accent,
                                foreground: _accentHover,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _agentSwitcherSubtitle(agent),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(alpha: 0.2),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: _accentHover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentGlyph extends StatelessWidget {
  const _AgentGlyph({
    required this.agent,
    required this.selected,
    required this.compact,
  });

  final AgentProfile agent;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseColor = agent.isDefault ? _accent : _accentAlt;
    final initials = _agentInitials(agent.displayName);
    final size = compact ? 38.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 11 : 12),
        gradient: LinearGradient(
          colors: <Color>[
            baseColor.withValues(alpha: selected ? 0.85 : 0.65),
            Color.lerp(
              baseColor,
              _bgSecondary,
              0.35,
            )!.withValues(alpha: selected ? 0.9 : 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: selected ? 0.34 : 0.2),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: baseColor.withValues(alpha: selected ? 0.22 : 0.12),
            blurRadius: compact ? 12 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            agent.canDelegate ? Icons.hub_rounded : Icons.smart_toy_outlined,
            size: compact ? 17 : 18,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Text(
            initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 12 : 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTag extends StatelessWidget {
  const _AgentTag({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

String _agentInitials(String label) {
  final parts = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// The foot of the rail: who is signed in, and the one way into Settings.
class _SidebarSettingsButton extends StatelessWidget {
  const _SidebarSettingsButton({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final label = controller.accountLabel.trim();
    final initial = label.isEmpty ? 'N' : label.characters.first.toUpperCase();
    final active = controller.selectedSection == AppSection.settings;
    final radius = BorderRadius.circular(18);
    return Material(
      color: active ? _accentMuted : _bgTertiary,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => controller.setSelectedSection(AppSection.settings),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: active ? _accent.withValues(alpha: 0.35) : _border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? _accent : _bgCard,
                  border: Border.all(color: active ? _accent : _borderLight),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: active ? _bgPrimary : _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geist(
                        color: _textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    Text(
                      appStrings.settings,
                      style: TextStyle(color: _textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.settings_outlined,
                size: 17,
                color: active ? _accent : _textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone header: the agent switcher. Settings, sign-out included, is a tab of
/// its own in the bottom bar.
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Row(
        children: <Widget>[
          _LiveMascot(controller: controller, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: controller.agentProfiles.isNotEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _AgentSwitcher(
                      controller: controller,
                      compact: true,
                    ),
                  )
                : Text(
                    'NeoAgent',
                    style: GoogleFonts.geist(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The sections of the open group, as a horizontally scrolling chip row.
///
/// This is what replaces the drawer's expandable tree on a phone: every
/// section in the group stays one tap away and visible, rather than hidden
/// behind a hamburger.
class _MobileSectionChips extends StatefulWidget {
  const _MobileSectionChips({
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  final List<AppSection> sections;
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  State<_MobileSectionChips> createState() => _MobileSectionChipsState();
}

class _MobileSectionChipsState extends State<_MobileSectionChips> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        key: const ValueKey<String>('mobile-section-chips'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: widget.sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = widget.sections[index];
          final active = section == widget.selected;
          return _SectionChip(
            section: section,
            active: active,
            onTap: () => widget.onSelect(section),
          );
        },
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.active,
    required this.onTap,
  });

  final AppSection section;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: active ? _accentMuted : _bgTertiary,
            border: Border.all(
              color: active ? _accent.withValues(alpha: 0.3) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                section.icon,
                size: 15,
                color: active ? _accent : _textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                section.label,
                style: GoogleFonts.geist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? _accentHover : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab per sidebar group the account can see.
class _MobileTabBar extends StatelessWidget {
  const _MobileTabBar({
    required this.controller,
    required this.selected,
    required this.onSelect,
  });

  final NeoAgentController controller;
  final SidebarGroup? selected;
  final ValueChanged<SidebarGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = SidebarGroup.values
        .where((group) => _groupSections(controller, group).isNotEmpty)
        .toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: _bgPrimary,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: groups
                .map(
                  (group) => Expanded(
                    child: _MobileTab(
                      group: group,
                      active: group == selected,
                      onTap: () => onSelect(group),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  const _MobileTab({
    required this.group,
    required this.active,
    required this.onTap,
  });

  final SidebarGroup group;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _accent : _textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(group.icon, size: 21, color: color),
              const SizedBox(height: 5),
              Text(
                group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.geist(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.controller, this.devicesPanelKey});

  final NeoAgentController controller;
  final GlobalKey? devicesPanelKey;

  @override
  Widget build(BuildContext context) {
    // While data loads, keep the page mounted (drafts, scroll and filters
    // survive) but hidden behind a skeleton, so its empty lists don't read as
    // "none". The page fades in as the skeleton fades out.
    final loading = controller.isAwaitingDataFor(controller.selectedSection);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Visibility(
          visible: !loading,
          maintainState: true,
          child: AnimatedOpacity(
            opacity: loading ? 0 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: _buildPage(),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: loading
              ? PageSkeleton(layout: _skeletonLayout)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  PageSkeletonLayout get _skeletonLayout {
    switch (controller.selectedSection) {
      case AppSection.chat:
        return PageSkeletonLayout.chat;
      case AppSection.settings:
        return PageSkeletonLayout.settings;
      default:
        return PageSkeletonLayout.list;
    }
  }

  Widget _buildPage() {
    switch (controller.selectedSection) {
      case AppSection.chat:
        return ChatPanel(controller: controller);
      case AppSection.voiceAssistant:
        return AgentCallScreen(controller: controller, embedded: true);
      case AppSection.devices:
        return DevicesPanel(key: devicesPanelKey, controller: controller);
      case AppSection.runs:
        return RunsAndLogsPanel(controller: controller);
      case AppSection.settings:
        return SettingsPanel(controller: controller);
      case AppSection.skills:
        return ToolsPanel(controller: controller);
      case AppSection.integrations:
        return ToolsPanel(controller: controller);
      case AppSection.memory:
        return MemoryPanel(controller: controller);
      case AppSection.tasks:
        return TasksPanel(controller: controller);
      case AppSection.mcp:
        return ToolsPanel(controller: controller);
      case AppSection.health:
        return controller.showHealthSection
            ? HealthPanel(controller: controller)
            : ChatPanel(controller: controller);
      case AppSection.team:
        return TeamPanel(controller: controller);
      case AppSection.admin:
        return controller.isAdmin
            ? AdminPanel(controller: controller)
            : ChatPanel(controller: controller);
    }
  }
}
