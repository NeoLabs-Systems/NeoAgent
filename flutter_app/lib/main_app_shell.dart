part of 'main.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppSplash());
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

/// The sign-in and registration fields, for inline errors.
enum _AuthField { signupKey, username, email, password, confirmPassword }

/// Which field a server error code concerns during registration.
_AuthField? _authFieldForCode(String? code) {
  switch (code) {
    case 'SIGNUP_KEY_REQUIRED':
    case 'SIGNUP_KEY_INVALID':
    case 'SIGNUP_KEY_USED':
      return _AuthField.signupKey;
    case 'USERNAME_TOO_SHORT':
    case 'USERNAME_TAKEN':
      return _AuthField.username;
    case 'EMAIL_TAKEN':
    case 'INVALID_EMAIL':
      return _AuthField.email;
    case 'PASSWORD_TOO_SHORT':
    case 'PASSWORD_WEAK':
      return _AuthField.password;
  }
  return null;
}

class _AuthViewState extends State<AuthView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _twoFactorController;
  final TextEditingController _signupKeyController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;
  bool _registerMode = false;

  /// The sign-up key the server accepted; the account form opens once set.
  String? _verifiedSignupKey;
  bool _obscurePassword = true;
  Map<_AuthField, String> _fieldErrors = const <_AuthField, String>{};

  /// Whether a QR code is on screen, inline or in the dialog; the challenge
  /// is only created and polled while one is and the app is in front.
  bool _inlineQrVisible = false;
  bool _qrDialogOpen = false;
  bool _appInForeground = true;
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
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
    unawaited(_refreshLocalRuntimeStatus());
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    // Inactive is an unfocused but visible desktop window; keep polling.
    _appInForeground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _applyQrVisibility();
  }

  void _setInlineQrVisible(bool visible) {
    if (_inlineQrVisible == visible) return;
    _inlineQrVisible = visible;
    // Called during build and layout; start or pause after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyQrVisibility());
  }

  void _applyQrVisibility() {
    if (!mounted) return;
    if ((_inlineQrVisible || _qrDialogOpen) && _appInForeground) {
      unawaited(widget.controller.prepareQrLoginChallenge());
    } else {
      widget.controller.pauseQrLoginPolling();
    }
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
    _signupKeyController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _lifecycle.dispose();
    widget.controller.pauseQrLoginPolling();
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
                                inlineError =
                                    appStrings.enterYourUsernameOrEmail;
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
    _qrDialogOpen = true;
    try {
      await widget.controller.prepareQrLoginChallenge();
      if (!mounted) {
        return;
      }
      await _showQrLoginDialogBody();
    } finally {
      _qrDialogOpen = false;
      _applyQrVisibility();
    }
  }

  Future<void> _showQrLoginDialogBody() async {
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
              return Center(
                child: _AuthQrPlate(
                  size: 280,
                  payload: canShowQr ? challenge!.qrPayload : null,
                  preparing: controller.isPreparingQrLogin,
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

  void _setRegisterMode(bool registerMode) {
    widget.controller.clearInlineError();
    setState(() {
      _registerMode = registerMode;
      _fieldErrors = const <_AuthField, String>{};
    });
  }

  /// Clears what the user just started fixing: the field's own error and the
  /// banner.
  void _onFieldEdited(_AuthField field) {
    widget.controller.clearInlineError();
    setState(() {
      if (_fieldErrors.containsKey(field)) {
        _fieldErrors = Map<_AuthField, String>.of(_fieldErrors)..remove(field);
      }
    });
  }

  /// The inline error for [field]: the form's own check, else a server error
  /// whose code concerns this field.
  String? _errorFor(_AuthField field) {
    final local = _fieldErrors[field];
    if (local != null) return local;
    final controller = widget.controller;
    if (_registerMode && _authFieldForCode(controller.authErrorCode) == field) {
      return controller.errorMessage;
    }
    return null;
  }

  _PasswordStrengthInfo get _registerPasswordStrength => _passwordStrengthInfo(
    password: _passwordController.text,
    username: _usernameController.text,
    email: _emailController.text,
  );

  /// Checks every registration field at once so all problems show together.
  bool _validateRegistration() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final strength = _registerPasswordStrength;
    final errors = <_AuthField, String>{
      if (username.isEmpty)
        _AuthField.username: appStrings.enterAUsername
      else if (username.length < 3)
        _AuthField.username: appStrings.authUsernameTooShort,
      if (!_looksLikeEmail(email))
        _AuthField.email: appStrings.enterAValidEmailAddress,
      if (password.isEmpty)
        _AuthField.password: appStrings.enterAPassword
      else if (!strength.acceptable)
        _AuthField.password: strength.message,
      if (password != _confirmPasswordController.text)
        _AuthField.confirmPassword: appStrings.passwordsDoNotMatch,
    };
    setState(() => _fieldErrors = errors);
    return errors.isEmpty;
  }

  /// Registration on a server that needs a key starts by asking for one.
  bool get _awaitingSignupKey =>
      _registerMode &&
      widget.controller.signupKeyRequired &&
      _verifiedSignupKey == null;

  Future<void> _submitSignupKey() async {
    final key = _signupKeyController.text.trim();
    if (key.isEmpty) {
      setState(
        () => _fieldErrors = <_AuthField, String>{
          _AuthField.signupKey: appStrings.signupKeyRequiredError,
        },
      );
      return;
    }
    final accepted = await widget.controller.checkSignupKey(key);
    if (!mounted || !accepted) return;
    setState(() {
      _verifiedSignupKey = key;
      _fieldErrors = const <_AuthField, String>{};
    });
    _usernameFocus.requestFocus();
  }

  /// A key the server turned down while creating the account (spent or
  /// revoked meanwhile) sends the form back to the key step, error and all.
  void _returnToKeyStepIfRejected() {
    if (!mounted ||
        _authFieldForCode(widget.controller.authErrorCode) !=
            _AuthField.signupKey) {
      return;
    }
    setState(() => _verifiedSignupKey = null);
  }

  void _changeSignupKey() {
    widget.controller.clearInlineError();
    setState(() {
      _verifiedSignupKey = null;
      _fieldErrors = const <_AuthField, String>{};
    });
  }

  Future<void> _registerWithProvider(String provider) async {
    await widget.controller.authenticateWithProvider(
      provider: provider,
      register: true,
      signupKey: _verifiedSignupKey,
    );
    _returnToKeyStepIfRejected();
  }

  bool _validateLogin() {
    final errors = <_AuthField, String>{
      if (_usernameController.text.trim().isEmpty)
        _AuthField.username: appStrings.enterYourUsernameOrEmail,
      if (_passwordController.text.isEmpty)
        _AuthField.password: appStrings.enterAPassword,
    };
    setState(() => _fieldErrors = errors);
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    if (controller.isAuthenticating) return;
    if (controller.isAwaitingTwoFactor) {
      final code = _twoFactorController.text.trim();
      if (code.isEmpty) {
        controller.showInlineError(appStrings.enterYour2faOrRecoveryCode);
        return;
      }
      await controller.completeTwoFactorLogin(code: code);
      if (!controller.isAwaitingTwoFactor) {
        _twoFactorController.clear();
      }
    } else if (_awaitingSignupKey) {
      await _submitSignupKey();
      return;
    } else if (_registerMode) {
      if (!_validateRegistration()) return;
      await controller.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        signupKey: _verifiedSignupKey,
      );
      _returnToKeyStepIfRejected();
      // Created but waiting on email confirmation: sign in once confirmed.
      if (mounted &&
          !controller.isAuthenticated &&
          controller.authInfoMessage != null) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _registerMode = false;
          _fieldErrors = const <_AuthField, String>{};
        });
      }
    } else {
      if (!_validateLogin()) return;
      await controller.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }
    if (controller.isAuthenticated) {
      TextInput.finishAutofillContext();
    }
  }

  Widget _passwordVisibilityToggle() {
    return IconButton(
      tooltip: _obscurePassword
          ? appStrings.authShowPassword
          : appStrings.authHidePassword,
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
    );
  }

  /// The mascot's face on the sign-in card follows what the form is doing.
  MascotMood get _authMood {
    final controller = widget.controller;
    if (controller.qrLoginScan != null && !_registerMode) {
      return MascotMood.waiting;
    }
    if (controller.isAuthenticating) return MascotMood.thinking;
    if (controller.errorMessage != null) return MascotMood.blocked;
    if (controller.isAwaitingTwoFactor) return MascotMood.listening;
    if (_registerMode &&
        _passwordController.text.isNotEmpty &&
        _registerPasswordStrength.acceptable) {
      return MascotMood.done;
    }
    return MascotMood.idle;
  }

  /// The theme's field, filled with the page color so it reads on the card.
  InputDecoration _authInputDecoration({
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _bgPrimary,
      errorText: errorText,
      suffixIcon: suffixIcon,
    );
  }

  /// A field with its label above it; [trailing] ends the label row. The
  /// label is the field's accessible name.
  Widget _labeledField(String label, Widget field, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              // The field announces the label itself, below.
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: field),
      ],
    );
  }

  ButtonStyle get _inlineLinkStyle => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );

  Widget _orDivider(String label) {
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: _border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: _textMuted, fontSize: 12)),
        ),
        Expanded(child: Divider(color: _border)),
      ],
    );
  }

  List<Widget> _buildCredentialFields() {
    final controller = widget.controller;
    final usernameField = TextField(
      controller: _usernameController,
      focusNode: _usernameFocus,
      autofillHints: const <String>[AutofillHints.username],
      keyboardType: _registerMode
          ? TextInputType.text
          : TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _onFieldEdited(_AuthField.username),
      onSubmitted: (_) =>
          (_registerMode ? _emailFocus : _passwordFocus).requestFocus(),
      decoration: _authInputDecoration(
        errorText: _errorFor(_AuthField.username),
      ),
    );
    final passwordField = TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: <String>[
        _registerMode ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: _registerMode
          ? TextInputAction.next
          : TextInputAction.done,
      onChanged: (_) => _onFieldEdited(_AuthField.password),
      onSubmitted: (_) => _registerMode
          ? _confirmPasswordFocus.requestFocus()
          : unawaited(_submit()),
      decoration: _authInputDecoration(
        errorText: _errorFor(_AuthField.password),
        suffixIcon: _passwordVisibilityToggle(),
      ),
    );
    if (!_registerMode) {
      final forgotPassword =
          controller.hasUser && controller.serviceEmailConfigured
          ? TextButton(
              onPressed: controller.isAuthenticating
                  ? null
                  : _showForgotPasswordDialog,
              style: _inlineLinkStyle,
              child: Text(appStrings.forgotPassword),
            )
          : null;
      return <Widget>[
        _labeledField(appStrings.usernameOrEmail, usernameField),
        const SizedBox(height: 14),
        _labeledField(
          appStrings.password,
          passwordField,
          trailing: forgotPassword,
        ),
      ];
    }
    return <Widget>[
      _labeledField(appStrings.username, usernameField),
      const SizedBox(height: 14),
      _labeledField(
        appStrings.email,
        TextField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
          onChanged: (_) => _onFieldEdited(_AuthField.email),
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: _authInputDecoration(
            errorText: _errorFor(_AuthField.email),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _labeledField(appStrings.password, passwordField),
      const SizedBox(height: 10),
      _PasswordStrengthIndicator(info: _registerPasswordStrength),
      const SizedBox(height: 14),
      _labeledField(
        appStrings.confirmPassword2,
        TextField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocus,
          obscureText: _obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: (_) => _onFieldEdited(_AuthField.confirmPassword),
          onSubmitted: (_) => unawaited(_submit()),
          decoration: _authInputDecoration(
            errorText: _errorFor(_AuthField.confirmPassword),
            suffixIcon: _passwordVisibilityToggle(),
          ),
        ),
      ),
    ];
  }

  Widget _buildSignupKeyField() {
    return _labeledField(
      appStrings.signupKey,
      TextField(
        controller: _signupKeyController,
        autofocus: true,
        keyboardType: TextInputType.visiblePassword,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: <TextInputFormatter>[_SignupKeyFormatter()],
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: GoogleFonts.geistMono(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
        onChanged: (_) => _onFieldEdited(_AuthField.signupKey),
        onSubmitted: (_) => unawaited(_submit()),
        decoration: _authInputDecoration(
          errorText: _errorFor(_AuthField.signupKey),
        ).copyWith(hintText: 'XXXX-XXXX-XXXX'),
      ),
    );
  }

  /// The accepted key above the account form, with a way back to change it.
  Widget _buildSignupKeySummary(String key) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: _success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _success.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.vpn_key_outlined, size: 16, color: _success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              key,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.geistMono(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.controller.isAuthenticating
                ? null
                : _changeSignupKey,
            style: _inlineLinkStyle,
            child: Text(appStrings.signupKeyChange),
          ),
        ],
      ),
    );
  }

  /// Phone sign-in, the quickest way in: the code itself where the card has
  /// room, else a row that opens it in a dialog.
  Widget _buildQrLoginBlock(NeoAgentController controller) {
    final challenge = controller.qrLoginChallenge;
    final canShowQr =
        challenge?.isUsable == true && !(challenge?.isExpired ?? true);
    final countdown = challenge?.secondsRemaining ?? 0;
    final decoration = BoxDecoration(
      color: _bgPrimary,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _accent.withValues(alpha: 0.38)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= 340;
        _setInlineQrVisible(inline);
        final Widget block;
        if (inline) {
          block = Container(
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: Row(
              children: <Widget>[
                _AuthQrPlate(
                  size: 116,
                  payload: canShowQr ? challenge!.qrPayload : null,
                  preparing: controller.isPreparingQrLogin,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        appStrings.scanWithNeoagentOnYourPhone,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appStrings.onASignedInAndroidDevice,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              canShowQr
                                  ? appStrings.refreshesInArg1S(countdown)
                                  : appStrings.waitingForCode,
                              style: GoogleFonts.geistMono(
                                color: _textMuted,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: appStrings.refreshCode,
                            onPressed: controller.isPreparingQrLogin
                                ? null
                                : () => unawaited(
                                    controller.prepareQrLoginChallenge(
                                      force: true,
                                    ),
                                  ),
                            color: _textSecondary,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          block = Material(
            color: Colors.transparent,
            child: Ink(
              decoration: decoration,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: controller.isPreparingQrLogin
                    ? null
                    : _showQrLoginDialog,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _AuthQrPlate.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: _qrDarkColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              canShowQr
                                  ? appStrings.showQrCode
                                  : appStrings.prepareQrCode,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appStrings.scanWithNeoagentOnYourPhone,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: _textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            block,
            if (controller.qrLoginErrorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              _InlineError(message: controller.qrLoginErrorMessage!),
            ],
          ],
        );
      },
    );
  }

  /// Google, other providers and security keys; two fit side by side.
  Widget _buildAlternativeSignIns(
    NeoAgentController controller,
    List<AuthProviderCatalogItem> providers,
    bool showSecurityKeySignIn,
  ) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(46),
      foregroundColor: _textPrimary,
      side: BorderSide(color: _borderLight),
    );
    final buttons = <Widget>[
      for (final provider in providers)
        OutlinedButton.icon(
          onPressed: controller.isAuthenticating
              ? null
              : () => _registerMode
                    ? unawaited(_registerWithProvider(provider.id))
                    : unawaited(
                        controller.authenticateWithProvider(
                          provider: provider.id,
                          register: false,
                        ),
                      ),
          style: style,
          icon: AuthProviderIcon(provider: provider.icon),
          label: Text(
            _registerMode
                ? appStrings.registerWithArg1(provider.label)
                : provider.label,
          ),
        ),
      if (showSecurityKeySignIn)
        OutlinedButton.icon(
          onPressed: controller.isAuthenticating
              ? null
              : () => controller.signInWithSecurityKey(
                  username: _usernameController.text,
                ),
          style: style,
          icon: const Icon(Icons.key, size: 18),
          label: Text(appStrings.securityKey),
        ),
    ];
    if (buttons.length == 2 && !_registerMode) {
      return Row(
        children: <Widget>[
          Expanded(child: buttons[0]),
          const SizedBox(width: 10),
          Expanded(child: buttons[1]),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, button) in buttons.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: 10),
          button,
        ],
      ],
    );
  }

  /// A phone scanned the code: the card waits for its decision.
  Widget _buildQrWaitingContent(
    NeoAgentController controller,
    QrLoginScan scan,
  ) {
    final location = scan.requestLocationLabel.trim().ifEmpty('Unknown');
    Widget detail(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: _textMuted, fontSize: 12.5)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: _textPrimary, fontSize: 12.5)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          appStrings.qrLoginWaitingTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          appStrings.qrLoginWaitingBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgPrimary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accentMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      scan.scannerDeviceClass == 'tablet'
                          ? Icons.tablet_mac_rounded
                          : Icons.smartphone_rounded,
                      color: _accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      scan.scannerLabel,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              ...<Widget>[
                const SizedBox(height: 14),
                Divider(height: 1, color: _border),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (scan.requestedDeviceLabel.isNotEmpty)
                      Expanded(
                        child: detail(
                          appStrings.qrLoginSigningInOn,
                          scan.requestedDeviceLabel,
                        ),
                      ),
                    Expanded(
                      child: detail(appStrings.qrLoginLocation, location),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _WaitingDots(color: _accent),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                appStrings.qrLoginWaitingForApproval.toUpperCase(),
                style: GoogleFonts.geistMono(
                  color: _accentHover,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        if (controller.qrLoginErrorMessage != null) ...<Widget>[
          const SizedBox(height: 14),
          _InlineError(message: controller.qrLoginErrorMessage!),
        ],
        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: controller.isPreparingQrLogin
              ? null
              : () => unawaited(controller.cancelQrLoginScan()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: _textPrimary,
            side: BorderSide(color: _borderLight),
          ),
          child: Text(appStrings.qrLoginCancelAndUsePassword),
        ),
      ],
    );
  }

  Widget _buildAuthCardContent({
    required NeoAgentController controller,
    required List<AuthProviderCatalogItem> availableProviders,
    required bool awaitingTwoFactor,
    required bool showQrLogin,
    required String title,
    required String subtitle,
  }) {
    if (controller.isAwaitingProviderUsername) {
      return _ProviderUsernameForm(controller: controller);
    }
    final showSecurityKeySignIn =
        !_registerMode && controller.supportsSecurityKeys;
    final awaitingSignupKey = !awaitingTwoFactor && _awaitingSignupKey;
    final verifiedSignupKey = _verifiedSignupKey;
    // Field-specific server errors sit under their field, not in the banner.
    final showErrorBanner =
        controller.errorMessage != null &&
        !(_registerMode && _authFieldForCode(controller.authErrorCode) != null);
    final submitBlocked =
        _registerMode &&
        !awaitingTwoFactor &&
        !awaitingSignupKey &&
        !_registerPasswordStrength.acceptable;
    final hasAlternatives =
        !awaitingSignupKey &&
        (availableProviders.isNotEmpty || showSecurityKeySignIn);
    final scan = controller.qrLoginScan;
    if (showQrLogin && scan != null) {
      return _buildQrWaitingContent(controller, scan);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (awaitingTwoFactor) ...<Widget>[
          Text(
            appStrings.verification.toUpperCase(),
            textAlign: TextAlign.center,
            style: _sectionEyebrowStyle(),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          awaitingTwoFactor ? appStrings.enter2faCode : title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          awaitingTwoFactor
              ? appStrings.openYourAuthenticatorAppAndEnterThe
              : subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.45),
        ),
        if (showErrorBanner) ...<Widget>[
          const SizedBox(height: 20),
          _InlineError(
            message: controller.errorMessage!,
            onDismiss: controller.clearInlineError,
          ),
        ],
        if (controller.authInfoMessage != null) ...<Widget>[
          const SizedBox(height: 16),
          _InlineSuccess(message: controller.authInfoMessage!),
        ],
        if (showQrLogin) ...<Widget>[
          const SizedBox(height: 26),
          _buildQrLoginBlock(controller),
          const SizedBox(height: 22),
          _orDivider(appStrings.authOrUsePassword),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 24),
        if (awaitingTwoFactor)
          _labeledField(
            appStrings.n2faOrRecoveryCode,
            TextField(
              controller: _twoFactorController,
              autofocus: true,
              // Recovery codes are alphanumeric (XXXXX-XXXXX).
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const <String>[AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              style: GoogleFonts.geistMono(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
              onSubmitted: (_) => unawaited(_submit()),
              decoration: _authInputDecoration(),
            ),
          )
        else if (awaitingSignupKey)
          _buildSignupKeyField()
        else
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_registerMode && verifiedSignupKey != null) ...<Widget>[
                  _buildSignupKeySummary(verifiedSignupKey),
                  const SizedBox(height: 16),
                ],
                ..._buildCredentialFields(),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: controller.isAuthenticating || submitBlocked
              ? null
              : () => unawaited(_submit()),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: controller.isAuthenticating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  awaitingTwoFactor
                      ? appStrings.authVerify
                      : awaitingSignupKey
                      ? appStrings.continue2
                      : (_registerMode
                            ? appStrings.authCreateAccount
                            : appStrings.signIn),
                ),
        ),
        if (awaitingTwoFactor) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.isAuthenticating
                ? null
                : controller.cancelTwoFactorLogin,
            child: Text(appStrings.backToSignIn),
          ),
        ] else ...<Widget>[
          if (hasAlternatives) ...<Widget>[
            if (showQrLogin)
              const SizedBox(height: 12)
            else ...<Widget>[
              const SizedBox(height: 20),
              _orDivider(appStrings.orContinueWith),
              const SizedBox(height: 14),
            ],
            _buildAlternativeSignIns(
              controller,
              availableProviders,
              showSecurityKeySignIn,
            ),
          ],
          if (!_registerMode &&
              controller.hasUser &&
              !controller.serviceEmailConfigured) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              appStrings.authForgotPasswordAskAdmin,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.45),
            ),
          ],
        ],
        if (_showsLocalServerRepair) ...<Widget>[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _openLocalServerSettings,
            icon: const Icon(Icons.dns_outlined, size: 18),
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

  /// The card, with the mascot set into its top edge.
  Widget _buildAuthCard({required Widget child, required bool compact}) {
    const mascotSize = 76.0;
    const ring = 6.0;
    const overlap = mascotSize / 2 + ring;
    final side = compact ? 20.0 : 32.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: overlap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border),
              boxShadow: _softPanelShadow,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(side, overlap + 18, side, 28),
              child: child,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(ring),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(34),
          ),
          child: NeoMascot(mood: _authMood, size: mascotSize),
        ),
      ],
    );
  }

  List<Widget> _buildAuthFooter(
    NeoAgentController controller, {
    required bool awaitingTwoFactor,
    required bool showRegisterToggle,
  }) {
    if (awaitingTwoFactor || widget.controller.isAwaitingProviderUsername)
      return const <Widget>[];
    final backendHost =
        Uri.tryParse(controller.backendUrl)?.authority ?? controller.backendUrl;
    return <Widget>[
      if (showRegisterToggle) ...<Widget>[
        const SizedBox(height: 16),
        TextButton(
          onPressed: controller.isAuthenticating
              ? null
              : () => _setRegisterMode(!_registerMode),
          child: Text(
            _registerMode
                ? appStrings.alreadyHaveAnAccountSignIn
                : appStrings.needANewAccountRegister,
          ),
        ),
      ],
      if (controller.canChangeBackend) ...<Widget>[
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: <Widget>[
            Text(
              appStrings.authSigningInToArg1(backendHost),
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            TextButton(
              onPressed: controller.isAuthenticating
                  ? null
                  : () => unawaited(controller.changeBackend()),
              style: _inlineLinkStyle,
              child: Text(appStrings.authChangeServer),
            ),
          ],
        ),
      ],
    ];
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

    final awaitingTwoFactor = controller.isAwaitingTwoFactor;
    final showRegisterToggle = controller.hasUser;
    final showQrLogin =
        !awaitingTwoFactor &&
        !controller.isAwaitingProviderUsername &&
        !_registerMode;
    final waitingForPhone = showQrLogin && controller.qrLoginScan != null;
    if (!showQrLogin) {
      _setInlineQrVisible(false);
    } else if (waitingForPhone) {
      // The challenge is still live while the phone decides; keep polling,
      // and the card takes over from a code dialog.
      _setInlineQrVisible(true);
      if (_qrDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _qrDialogOpen) Navigator.of(context).pop();
        });
      }
    }
    final title = _registerMode
        ? (controller.hasUser
              ? appStrings.authCreateAccount
              : appStrings.createTheFirstAccount)
        : appStrings.authSignInTitle;
    final subtitle = _registerMode
        ? (!controller.hasUser
              ? appStrings.thisAccountWillUnlockNeoagentOn
              : _awaitingSignupKey
              ? appStrings.signupKeyStepSubtitle
              : appStrings.createAnotherNeoagentAccount)
        : appStrings.authSignInSubtitle;

    return _AuthBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              final compact =
                  viewportConstraints.maxWidth < AppBreakpoints.mobile;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 24,
                      vertical: compact ? 20 : 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _EntranceMotion(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildAuthCard(
                                compact: compact,
                                child: _buildAuthCardContent(
                                  controller: controller,
                                  availableProviders: availableProviders,
                                  awaitingTwoFactor: awaitingTwoFactor,
                                  showQrLogin: showQrLogin,
                                  title: title,
                                  subtitle: subtitle,
                                ),
                              ),
                              ..._buildAuthFooter(
                                controller,
                                awaitingTwoFactor:
                                    awaitingTwoFactor || waitingForPhone,
                                showRegisterToggle: showRegisterToggle,
                              ),
                            ],
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

/// Three dots stepping in turn while the phone decides; still when the
/// platform asks for reduced motion.
class _WaitingDots extends StatefulWidget {
  const _WaitingDots({required this.color});

  final Color color;

  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots> {
  Timer? _timer;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 400),
        (_) => setState(() => _step = (_step + 1) % 3),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _timer == null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 3; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: still || i == _step
                  ? widget.color
                  : widget.color.withValues(alpha: 0.25),
            ),
          ),
        ],
      ],
    );
  }
}

/// The QR code on its paper plate: dark modules on a light ground so phone
/// cameras read it in either theme.
class _AuthQrPlate extends StatelessWidget {
  const _AuthQrPlate({
    required this.size,
    required this.payload,
    required this.preparing,
  });

  static const Color paper = Color(0xFFF4F1E8);

  final double size;
  final String? payload;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    final data = payload;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(size * 0.12),
      ),
      child: data != null
          ? QrImageView(
              data: data,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _qrDarkColor,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _qrDarkColor,
              ),
            )
          : Center(
              child: preparing
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _qrDarkColor,
                      ),
                    )
                  : Icon(
                      Icons.qr_code_2_rounded,
                      size: size * 0.4,
                      color: _qrDarkColor.withValues(alpha: 0.35),
                    ),
            ),
    );
  }
}

/// The sign-in page ground: the mascot's dot matrix, faint, with a soft glow
/// where the card sits.
class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(color: _bgPrimary),
      child: CustomPaint(
        painter: _AuthBackdropPainter(
          dot: _textPrimary.withValues(alpha: isLight ? 0.09 : 0.07),
          glow: _accent.withValues(alpha: isLight ? 0.08 : 0.10),
        ),
        child: child,
      ),
    );
  }
}

class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter({required this.dot, required this.glow});

  static const double _pitch = 22;
  static const double _glowRadius = 380;

  final Color dot;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.3);
    canvas.drawCircle(
      centre,
      _glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[glow, glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: _glowRadius)),
    );
    final points = <Offset>[
      for (var y = _pitch / 2; y < size.height; y += _pitch)
        for (var x = _pitch / 2; x < size.width; x += _pitch) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = dot
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AuthBackdropPainter oldDelegate) =>
      oldDelegate.dot != dot || oldDelegate.glow != glow;
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
  bool _phoneSyncOffered = false;

  @override
  void initState() {
    super.initState();
    _syncPhoneTriggers();
    widget.controller.phoneSync.addListener(_maybeOfferPhoneSync);
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
      oldWidget.controller.phoneSync.removeListener(_maybeOfferPhoneSync);
      widget.controller.addListener(_handleControllerChanged);
      widget.controller.phoneSync.addListener(_maybeOfferPhoneSync);
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
    widget.controller.phoneSync.removeListener(_maybeOfferPhoneSync);
    super.dispose();
  }

  /// Once the phone's sharing state is known after sign-in, asks once whether
  /// to share its calendar and contacts.
  void _maybeOfferPhoneSync() {
    if (_phoneSyncOffered || !widget.controller.phoneSync.shouldOfferSetup) {
      return;
    }
    _phoneSyncOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offerPhoneSyncSetup(context, widget.controller);
    });
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
    final inCall =
        controller.incomingAgentCall != null ||
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
                      appStrings.chooseWhereThisPersonShouldBe(
                        widget.controller.activeAgentLabel,
                      ),
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

/// Sign-up keys as XXXX-XXXX-XXXX while they are typed or pasted: upper case,
/// grouped by fours, anything else dropped. The server accepts them either way.
class _SignupKeyFormatter extends TextInputFormatter {
  static const int _length = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (raw.length > _length) raw = raw.substring(0, _length);
    final grouped = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && index % 4 == 0) grouped.write('-');
      grouped.write(raw[index]);
    }
    final text = grouped.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
