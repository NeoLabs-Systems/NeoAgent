part of 'main.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
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
              Text('Loading NeoAgent'),
            ],
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
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _registerMode = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.controller.username,
    );
    _passwordController = TextEditingController(
      text: widget.controller.password,
    );
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.hasUser) {
      _registerMode = true;
    }

    final title = _registerMode ? 'Create the first account' : 'Sign in';
    final subtitle = _registerMode
        ? 'This account will unlock the workspace.'
        : 'Enter your NeoAgent account details.';

    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: <Widget>[
          const Positioned(
            top: -100,
            left: -100,
            child: _BlurOrb(size: 500, color: _accent),
          ),
          const Positioned(
            right: -80,
            bottom: -80,
            child: _BlurOrb(size: 400, color: Color(0xFF8B5CF6)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    color: const Color.fromRGBO(12, 12, 24, 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: _borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Column(
                            children: <Widget>[
                              _LogoBadge(size: 52),
                              SizedBox(height: 16),
                              Text(
                                'NeoAgent',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 20),
                          if (controller.errorMessage != null) ...<Widget>[
                            _InlineError(message: controller.errorMessage!),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          if (_registerMode) ...<Widget>[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm Password',
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: controller.isAuthenticating
                                ? null
                                : () async {
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
                                        password: _passwordController.text,
                                      );
                                    } else {
                                      await controller.login(
                                        username: _usernameController.text,
                                        password: _passwordController.text,
                                      );
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                    _registerMode
                                        ? 'Create account'
                                        : 'Sign in',
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
        ],
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
      return Scaffold(
        backgroundColor: _bgPrimary,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              _Sidebar(controller: controller),
              Expanded(child: _SectionBody(controller: controller)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgPrimary,
      drawer: _MobileDrawer(controller: controller),
      appBar: AppBar(
        title: Text(controller.selectedSection.navigationTitle),
        actions: <Widget>[
          IconButton(
            onPressed: controller.isRefreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _SectionBody(controller: controller)),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (notice.meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        notice.meta,
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
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
                              icon: const Icon(Icons.verified_user_outlined),
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
                child: const Text('Open Messaging'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Dismiss'),
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
  const _Sidebar({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: _bgSecondary,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: <Widget>[
                const _LogoBadge(size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'NeoAgent',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.accountLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _buildSidebarItems(
                controller,
                onSelect: controller.setSelectedSection,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Column(
              children: <Widget>[
                _SidebarButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onTap: controller.isRefreshing ? null : controller.refresh,
                ),
                _SidebarButton(
                  label: 'Logout',
                  icon: Icons.logout,
                  onTap: controller.logout,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: controller.socketConnected ? _success : _warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.socketConnected ? 'Live' : 'Offline',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
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

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _bgSecondary,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: <Widget>[
                  const _LogoBadge(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      controller.accountLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  _SidebarButton(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.refresh();
                    },
                  ),
                  _SidebarButton(
                    label: 'Logout',
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
      case AppSection.logs:
        return LogsPanel(controller: controller);
      case AppSection.skills:
        return SkillsPanel(controller: controller);
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
