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
              _LogoBadge(size: 52),
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
    _backendUrlController = TextEditingController(text: widget.controller.backendUrl);
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
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _panelGradient,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: _borderLight),
                    boxShadow: _softPanelShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(34, 32, 34, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _LogoBadge(size: 60),
                        const SizedBox(height: 22),
                        Text('FIRST-RUN SETUP', style: _sectionEyebrowStyle()),
                        const SizedBox(height: 10),
                        Text(
                          'Connect this build to your NeoAgent backend',
                          style: _displayTitleStyle(34),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This build was not bundled with a backend endpoint. Enter your NeoAgent server URL once and the app will store it locally for future launches.',
                          style: TextStyle(color: _textSecondary, height: 1.55),
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
                        if (controller.errorMessage case final message?) ...<Widget>[
                          const SizedBox(height: 16),
                          _InlineError(message: message),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: controller.isSavingBackendUrl ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 468),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: _panelGradient,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: _borderLight),
                            boxShadow: _softPanelShadow,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Column(
                                  children: <Widget>[
                                    const _LogoBadge(size: 58),
                                    const SizedBox(height: 18),
                                    Text(
                                      'NeoOS',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 26),
                                Text(
                                  awaitingTwoFactor
                                      ? 'Verification'
                                      : title.toUpperCase(),
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
                                  style: TextStyle(
                                    color: _textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (controller.errorMessage !=
                                    null) ...<Widget>[
                                  _InlineError(
                                    message: controller.errorMessage!,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (controller.authInfoMessage !=
                                    null) ...<Widget>[
                                  _InlineSuccess(
                                    message: controller.authInfoMessage!,
                                  ),
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
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _passwordController,
                                    onChanged: (_) => setState(() {}),
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    ),
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
                                      autofillHints: const <String>[
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Confirm Password',
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 22),
                                FilledButton(
                                  onPressed: controller.isAuthenticating
                                      ? null
                                      : () async {
                                          if (awaitingTwoFactor) {
                                            await controller
                                                .completeTwoFactorLogin(
                                                  code:
                                                      _twoFactorController.text,
                                                );
                                            return;
                                          }
                                          if (_registerMode &&
                                              _passwordController.text !=
                                                  _confirmPasswordController
                                                      .text) {
                                            widget.controller.showInlineError(
                                              'Passwords do not match.',
                                            );
                                            return;
                                          }
                                          if (_registerMode) {
                                            await controller.register(
                                              username:
                                                  _usernameController.text,
                                              email: _emailController.text,
                                              password:
                                                  _passwordController.text,
                                            );
                                          } else {
                                            await controller.login(
                                              username:
                                                  _usernameController.text,
                                              password:
                                                  _passwordController.text,
                                            );
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(58),
                                  ),
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
                                              : _registerMode
                                              ? 'Create account'
                                              : 'Sign in',
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
                                  if (availableProviders
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Divider(color: _borderLight),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            'or continue with',
                                            style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(color: _borderLight),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ...availableProviders.map(
                                      (provider) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: controller.isAuthenticating
                                              ? null
                                              : () => controller
                                                    .authenticateWithProvider(
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
                                            minimumSize: const Size.fromHeight(
                                              54,
                                            ),
                                            backgroundColor: _bgPrimary
                                                .withValues(alpha: 0.18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!_registerMode &&
                                      controller
                                          .serviceEmailConfigured) ...<Widget>[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: controller.isAuthenticating
                                          ? null
                                          : _showForgotPasswordDialog,
                                      child: const Text('Forgot password?'),
                                    ),
                                    if (!showRegisterToggle)
                                      const SizedBox(height: 12),
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
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _panelGradient,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: _borderLight),
                        boxShadow: _softPanelShadow,
                      ),
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
            child: Container(
              decoration: BoxDecoration(
                gradient: _panelGradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _borderLight),
                boxShadow: _softPanelShadow,
              ),
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
                                await widget.controller.allowMessagingEntry(
                                  notice.platform,
                                  suggestion.entry,
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
    return Container(
      width: 254,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            _bgSecondary.withValues(alpha: 0.96),
            _bgTertiary.withValues(alpha: 0.92),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _borderLight),
        boxShadow: _softPanelShadow,
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
                    const _LogoBadge(size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'NeoOS',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'by NeoLabs',
                            style: TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
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
                      const _LogoBadge(size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'NeoOS',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'by NeoLabs',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
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
      case AppSection.scheduler:
        return SchedulerPanel(controller: controller);
      case AppSection.mcp:
        return McpPanel(controller: controller);
      case AppSection.health:
        return controller.showHealthSection
            ? HealthPanel(controller: controller)
            : ChatPanel(controller: controller);
    }
  }
}
