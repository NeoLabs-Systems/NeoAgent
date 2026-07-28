part of 'main.dart';

class BackendSetupView extends StatefulWidget {
  const BackendSetupView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<BackendSetupView> createState() => _BackendSetupViewState();
}

class _BackendSetupViewState extends State<BackendSetupView> {
  late final TextEditingController _backendUrlController;
  bool _localInstall = false;
  bool _showAdvanced = false;

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

  Future<void> _connectCandidate(BackendDiscoveryCandidate candidate) async {
    _backendUrlController.text = candidate.backendUrl;
    await widget.controller.saveBackendUrl(candidate.backendUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_localInstall) {
      return _LocalInstallWidget(
        controller: widget.controller,
        onBack: () => setState(() => _localInstall = false),
      );
    }
    final controller = widget.controller;
    final candidates = controller.discoveredBackends;
    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
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
                            'WELCOME TO NEOAGENT',
                            style: _sectionEyebrowStyle(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Set up or connect NeoAgent',
                            style: _displayTitleStyle(34),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Install NeoAgent on this computer without a terminal, or connect to one that is already running.',
                            style: TextStyle(
                              color: _textSecondary,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_supportsDesktopShell) ...<Widget>[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    setState(() => _localInstall = true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _accent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text(
                                  'Set up NeoAgent on this computer',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Nearby NeoAgent servers',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Search again',
                                onPressed: controller.isDiscoveringBackends
                                    ? null
                                    : controller.discoverBackends,
                                icon: controller.isDiscoveringBackends
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (controller.isDiscoveringBackends &&
                              candidates.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _bgSecondary.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _borderLight),
                              ),
                              child: const Row(
                                children: <Widget>[
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Looking on this computer and your local network…',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!controller.isDiscoveringBackends &&
                              candidates.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _bgSecondary.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _borderLight),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.radar_rounded, color: _textMuted),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No other NeoAgent server was found. You can search again or enter an address manually.',
                                      style: TextStyle(
                                        color: _textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final candidate in candidates) ...<Widget>[
                            Material(
                              color: _bgSecondary.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: controller.isSavingBackendUrl
                                    ? null
                                    : () => _connectCandidate(candidate),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _borderLight),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: _accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          candidate.isLocal
                                              ? Icons.computer_rounded
                                              : Icons.dns_outlined,
                                          color: _accent,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              candidate.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              candidate.claimed
                                                  ? 'Ready to sign in'
                                                  : 'Ready for first-time setup',
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_rounded),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (controller.errorMessage
                              case final message?) ...<Widget>[
                            const SizedBox(height: 16),
                            _InlineError(message: message),
                          ],
                          const SizedBox(height: 10),
                          ExpansionTile(
                            initiallyExpanded: _showAdvanced,
                            onExpansionChanged: (value) =>
                                setState(() => _showAdvanced = value),
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: const Text('Enter an address manually'),
                            subtitle: const Text(
                              'For hosted or advanced network setups',
                            ),
                            children: <Widget>[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _backendUrlController,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'NeoAgent server address',
                                  prefixIcon: Icon(Icons.dns_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: controller.isSavingBackendUrl
                                      ? null
                                      : _submit,
                                  icon: controller.isSavingBackendUrl
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    controller.isSavingBackendUrl
                                        ? 'Connecting…'
                                        : 'Connect to this server',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (controller.backendDiscoveryErrorMessage
                              case final discoveryError?) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              discoveryError,
                              style: TextStyle(color: _textMuted, fontSize: 12),
                            ),
                          ],
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

// ─── Local Install Widget ────────────────────────────────────────────────────
