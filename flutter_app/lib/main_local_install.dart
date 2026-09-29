part of 'main.dart';

enum _LocalInstallPhase { choose, installing, done, failed }

class _LocalInstallWidget extends StatefulWidget {
  const _LocalInstallWidget({required this.controller, required this.onBack});

  final NeoAgentController controller;
  final VoidCallback onBack;

  @override
  State<_LocalInstallWidget> createState() => _LocalInstallWidgetState();
}

class _LocalInstallWidgetState extends State<_LocalInstallWidget> {
  _LocalInstallPhase _phase = _LocalInstallPhase.choose;
  LocalBackendSetupProfile _profile = LocalBackendSetupProfile.quick;
  String _channel = runtimeReleaseChannel;
  late final LocalBackendInstaller _installer;
  StreamSubscription<LocalBackendInstallEvent>? _eventSubscription;
  final List<LocalBackendInstallEvent> _events = <LocalBackendInstallEvent>[];
  LocalBackendInstallEvent? _currentEvent;
  LocalBackendInstallResult? _result;
  String? _errorMessage;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _installer = LocalBackendInstaller();
    _eventSubscription = _installer.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _currentEvent = event;
        _events.add(event);
      });
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _installer.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() {
      _phase = _LocalInstallPhase.installing;
      _events.clear();
      _currentEvent = null;
      _errorMessage = null;
    });
    try {
      final result = await _installer.install(_profile, channel: _channel);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _LocalInstallPhase.done;
      });
    } on LocalBackendInstallerException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = appStrings.arg1Arg2(error.message, error.code);
        _phase = _LocalInstallPhase.failed;
      });
    }
  }

  Future<void> _saveDiagnostics() async {
    final saved = await saveSetupDiagnostics(
      profile: _profile,
      events: _events,
    );
    if (!saved) return;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.diagnosticsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    return _ControlSurfaceBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _EntranceMotion(
                  child: _PanelSurface(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: _softPanelShadow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 28, 34, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: widget.onBack,
                            icon: Icon(Icons.arrow_back, size: 16),
                            label: Text(appStrings.back),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _BrandLockup(logoSize: 60),
                          const SizedBox(height: 22),
                          Text(appStrings.localSetup, style: _sectionEyebrowStyle()),
                          const SizedBox(height: 10),
                          Text(
                            appStrings.setUpNeoagentOnThisComputer,
                            style: _displayTitleStyle(28),
                          ),
                          const SizedBox(height: 20),
                          _buildContent(),
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

  Widget _buildContent() {
    switch (_phase) {
      case _LocalInstallPhase.choose:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              appStrings.chooseHowMuchYouWantTo,
              style: TextStyle(color: _textSecondary, height: 1.55),
            ),
            const SizedBox(height: 18),
            _SetupModeCard(
              selected: _profile == LocalBackendSetupProfile.quick,
              icon: Icons.bolt_rounded,
              title: appStrings.quickstart,
              description:
                  appStrings.installTheSecureCoreThenCreate,
              badge: 'Recommended',
              onTap: () =>
                  setState(() => _profile = LocalBackendSetupProfile.quick),
            ),
            const SizedBox(height: 10),
            _SetupModeCard(
              selected: _profile == LocalBackendSetupProfile.full,
              icon: Icons.tune_rounded,
              title: appStrings.fullSetup,
              description:
                  appStrings.installTheCoreWithExtraOptional,
              onTap: () =>
                  setState(() => _profile = LocalBackendSetupProfile.full),
            ),
            const SizedBox(height: 20),
            Text(appStrings.backendChannel, style: _sectionEyebrowStyle()),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'stable',
                  label: Text(appStrings.stable),
                  icon: Icon(Icons.verified_outlined),
                ),
                ButtonSegment<String>(
                  value: 'beta',
                  label: Text(appStrings.beta),
                  icon: Icon(Icons.science_outlined),
                ),
              ],
              selected: <String>{_channel},
              onSelectionChanged: (selection) {
                setState(() => _channel = selection.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _channel == 'beta'
                  ? appStrings.betaInstallsTheNewestPrereleaseBackendExpect
                  : appStrings.stableInstallsTheLatestPublishedBackend,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _install,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _profile == LocalBackendSetupProfile.quick
                      ? appStrings.startQuickstart
                      : appStrings.startFullSetup,
                ),
              ),
            ),
          ],
        );
      case _LocalInstallPhase.installing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_currentEvent?.message ?? appStrings.preparingNeoagent),
                ),
                TextButton(
                  onPressed: () {
                    _installer.cancel();
                    setState(() => _phase = _LocalInstallPhase.choose);
                  },
                  child: Text(appStrings.cancel),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: _currentEvent?.progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 14),
            ExpansionTile(
              initiallyExpanded: _showDetails,
              onExpansionChanged: (value) =>
                  setState(() => _showDetails = value),
              tilePadding: EdgeInsets.zero,
              title: Text(appStrings.setupDetails),
              children: <Widget>[
                for (final event in _events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          event.state == 'completed'
                              ? Icons.check_circle_outline
                              : event.state == 'failed'
                              ? Icons.error_outline
                              : Icons.circle_outlined,
                          size: 16,
                          color: event.state == 'failed'
                              ? _danger
                              : event.state == 'completed'
                              ? _success
                              : _textMuted,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            event.errorCode == null
                                ? event.message
                                : appStrings.arg1Arg2(event.message, event.errorCode),
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      case _LocalInstallPhase.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, color: _success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(appStrings.neoagentIsInstalledAndRunning),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _result == null
                    ? null
                    : () => widget.controller.saveBackendUrl(
                        _result!.backendUrl,
                        setupClaimToken: _result!.claimToken,
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _profile == LocalBackendSetupProfile.quick
                      ? appStrings.createYourAccount
                      : appStrings.continueFullSetup,
                ),
              ),
            ),
          ],
        );
      case _LocalInstallPhase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InlineError(
              message: _errorMessage ?? appStrings.neoagentSetupCouldNotFinish,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _install,
                    icon: Icon(Icons.build_outlined),
                    label: Text(appStrings.repairAndRetry),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () =>
                      setState(() => _phase = _LocalInstallPhase.choose),
                  child: Text(appStrings.changeSetupMode),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saveDiagnostics,
              icon: Icon(Icons.download_outlined),
              label: Text(appStrings.saveDiagnosticReport),
            ),
          ],
        );
    }
  }
}

class _SetupModeCard extends StatelessWidget {
  const _SetupModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: appStrings.arg1Arg27(title, description),
      child: Material(
        color: selected
            ? _accent.withValues(alpha: 0.08)
            : _bgSecondary.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _accent : _borderLight,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: selected ? _accent : _textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(color: _textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? _accent : _textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
