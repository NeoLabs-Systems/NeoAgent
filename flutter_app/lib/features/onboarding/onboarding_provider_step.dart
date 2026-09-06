import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../main.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';

class OnboardingProviderStep extends StatefulWidget {
  const OnboardingProviderStep({
    super.key,
    required this.onNext,
    required this.controller,
  });

  final VoidCallback onNext;
  final NeoAgentController controller;

  @override
  State<OnboardingProviderStep> createState() => _OnboardingProviderStepState();
}

class _OnboardingProviderStepState extends State<OnboardingProviderStep> {
  AiProviderMeta? _selected;
  bool _busy = false;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  List<AiProviderMeta> get _providers {
    final providers = List<AiProviderMeta>.from(
      widget.controller.aiProviders,
    );
    providers.sort((a, b) {
      final rank = _providerRank(a).compareTo(_providerRank(b));
      if (rank != 0) return rank;
      return a.label.compareTo(b.label);
    });
    return providers;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _select(AiProviderMeta provider) {
    setState(() {
      _selected = provider;
      _apiKeyController.clear();
      _baseUrlController.text = provider.baseUrl.isNotEmpty
          ? provider.baseUrl
          : provider.defaultBaseUrl;
    });
  }

  Future<void> _saveAndContinue() async {
    final provider = _selected;
    if (provider == null || provider.usesOAuth) {
      widget.onNext();
      return;
    }
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim().isNotEmpty
        ? _baseUrlController.text.trim()
        : provider.defaultBaseUrl;
    if (provider.usesApiKey && apiKey.isEmpty && !provider.credentialConfigured) {
      _showError('Enter an API key for ${provider.label}.');
      return;
    }
    if (provider.requiresBaseUrl && baseUrl.isEmpty) {
      _showError('A base URL is required for ${provider.label}.');
      return;
    }
    if (provider.usesApiKey && apiKey.isEmpty && !provider.supportsBaseUrl) {
      widget.onNext();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.saveAiProviderCredentials(
        providerId: provider.id,
        apiKey: provider.usesApiKey && apiKey.isNotEmpty ? apiKey : null,
        baseUrl: provider.supportsBaseUrl ? baseUrl : null,
      );
      if (mounted) widget.onNext();
    } catch (error) {
      _showError('Could not save ${provider.label}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    final selected = _selected;
    final width = MediaQuery.sizeOf(context).width;
    final useGrid = width >= 720;
    final canSave = selected != null && !selected.usesOAuth;

    return OnboardingScaffold(
      step: 2,
      totalSteps: 4,
      eyebrow: 'INTELLIGENCE',
      title: 'Connect an\nAI provider.',
      description:
          'Quickstart and full setup both finish here. Add a key now, or skip and do it in Settings.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          OnboardingGhostButton(
            label: 'Skip for now',
            onPressed: _busy ? null : widget.onNext,
          ),
          OnboardingPrimaryButton(
            label: canSave ? 'Save and continue' : 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _busy ? null : _saveAndContinue,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: providers.isEmpty
                ? Center(
                    child: Text(
                      'Provider catalog is unavailable.\nYou can add a key later in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: paletteOf(context).textMuted,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  )
                : useGrid
                ? GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 148,
                        ),
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return _ProviderChoiceCard(
                            provider: provider,
                            selected: selected?.id == provider.id,
                            compact: true,
                            onTap: () => _select(provider),
                          )
                          .animate()
                          .fadeIn(
                            duration: 420.ms,
                            delay: (180 + (index.clamp(0, 5) * 70)).ms,
                          )
                          .slideY(begin: 0.16, end: 0);
                    },
                  )
                : ListView.separated(
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return _ProviderChoiceCard(
                            provider: provider,
                            selected: selected?.id == provider.id,
                            onTap: () => _select(provider),
                          )
                          .animate()
                          .fadeIn(
                            duration: 420.ms,
                            delay: (180 + (index.clamp(0, 5) * 70)).ms,
                          )
                          .slideY(begin: 0.16, end: 0);
                    },
                  ),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 16),
            _ProviderCredentialFields(
              provider: selected,
              apiKeyController: _apiKeyController,
              baseUrlController: _baseUrlController,
            ),
          ],
        ],
      ),
    );
  }
}

int _providerRank(AiProviderMeta provider) {
  const preferred = <String>[
    'openai',
    'anthropic',
    'google',
    'grok',
    'openrouter',
    'ollama',
  ];
  if (provider.usesOAuth) return 200;
  final index = preferred.indexOf(provider.id);
  if (index >= 0) return index;
  return 50;
}

class _ProviderChoiceCard extends StatelessWidget {
  const _ProviderChoiceCard({
    required this.provider,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final AiProviderMeta provider;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final accent = provider.statusColor;
    return OnboardingOptionCard(
      selected: selected,
      accent: accent,
      compact: compact,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(provider.icon, color: accent, size: compact ? 22 : 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  provider.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.usesOAuth
                      ? 'Sign in with neoagent login'
                      : provider.isLocal
                      ? 'Local models on this computer'
                      : provider.credentialConfigured
                      ? 'Key saved'
                      : 'API key',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCredentialFields extends StatelessWidget {
  const _ProviderCredentialFields({
    required this.provider,
    required this.apiKeyController,
    required this.baseUrlController,
  });

  final AiProviderMeta provider;
  final TextEditingController apiKeyController;
  final TextEditingController baseUrlController;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    if (provider.usesOAuth) {
      return OnboardingPanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Sign in with `neoagent login ${provider.id}` in a terminal, then continue.',
          style: TextStyle(color: p.textSecondary, height: 1.45),
        ),
      );
    }
    return OnboardingPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          if (provider.usesApiKey)
            TextField(
              controller: apiKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: provider.credentialConfigured
                    ? '${provider.label} API key (saved)'
                    : '${provider.label} API key',
                hintText: provider.credentialConfigured ? '••••••••' : null,
              ),
            ),
          if (provider.usesApiKey && provider.supportsBaseUrl)
            const SizedBox(height: 12),
          if (provider.supportsBaseUrl)
            TextField(
              controller: baseUrlController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: provider.requiresBaseUrl
                    ? 'Base URL (required)'
                    : 'Base URL (optional)',
                hintText: provider.defaultBaseUrl.isEmpty
                    ? 'https://api.example.com/v1'
                    : provider.defaultBaseUrl,
              ),
            ),
        ],
      ),
    );
  }
}
