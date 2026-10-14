import 'package:flutter/material.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingMessagingStep extends StatefulWidget {
  const OnboardingMessagingStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.controller,
  });

  final VoidCallback onNext;
  final VoidCallback onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingMessagingStep> createState() =>
      _OnboardingMessagingStepState();
}

class _OnboardingMessagingStepState extends State<OnboardingMessagingStep> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Coming back to this step (or resuming onboarding) shows the platform
    // that is already connected instead of asking to connect again.
    for (final platform in messagingPlatforms) {
      if (_status(platform.id).isConnected) {
        _selectedId = platform.id;
        break;
      }
    }
  }

  MessagingPlatformStatus _status(String id) =>
      _controller.messagingStatuses[id] ?? MessagingPlatformStatus.empty(id);

  Future<void> _connect(MessagingPlatformDescriptor platform) async {
    try {
      await openMessagingConfig(context, _controller, platform);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.failedToConnectArg1(_controller.friendlyErrorMessage(e)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        MessagingPlatformDescriptor? selected;
        for (final platform in messagingPlatforms) {
          if (platform.id == _selectedId) selected = platform;
        }
        final query = _query.toLowerCase();
        // Connected platforms first, so a returning person sees them on top.
        final platforms =
            messagingPlatforms
                .where((p) => p.label.toLowerCase().contains(query))
                .toList()
              ..sort((a, b) {
                final aOn = _status(a.id).isConnected ? 0 : 1;
                final bOn = _status(b.id).isConnected ? 0 : 1;
                return aOn - bOn;
              });
        final connected = selected != null && _status(selected.id).isConnected;

        final Widget primary;
        if (selected == null || connected) {
          primary = OnboardingPrimaryButton(
            label: connected ? appStrings.onboardingNext : appStrings.continue2,
            icon: Icons.arrow_forward_rounded,
            onPressed: widget.onNext,
          );
        } else {
          final platform = selected;
          primary = OnboardingPrimaryButton(
            label: appStrings.connect,
            icon: Icons.link_rounded,
            onPressed: () => _connect(platform),
          );
        }

        return OnboardingScaffold(
          mood: MascotMood.listening,
          fill: true,
          eyebrow: appStrings.onboardingEyebrowCommunication,
          title: appStrings.connectAMessagingPlatform,
          description: appStrings.chooseOneToGetStartedNow,
          footer: OnboardingFooter(
            onBack: widget.onBack,
            secondary: <Widget>[
              if (!connected)
                OnboardingGhostButton(
                  label: appStrings.skipForNow,
                  onPressed: widget.onNext,
                ),
            ],
            primary: primary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: appStrings.onboardingSearchApps,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _PlatformList(
                  platforms: platforms,
                  selectedId: _selectedId,
                  isConnected: (id) => _status(id).isConnected,
                  onSelect: (id) => setState(
                    () => _selectedId = _selectedId == id ? null : id,
                  ),
                ),
              ),
              if (selected != null) ...<Widget>[
                const SizedBox(height: 12),
                _ConnectionState(
                  platform: selected,
                  status: _status(selected.id),
                  qr: _controller.pendingMessagingQr?.platform == selected.id
                      ? _controller.pendingMessagingQr
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Live connection state for the selected platform: the WhatsApp QR code
/// while it waits for a scan, then a confirmation once connected.
class _ConnectionState extends StatelessWidget {
  const _ConnectionState({
    required this.platform,
    required this.status,
    required this.qr,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingPlatformStatus status;
  final MessagingQrState? qr;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    if (status.isConnected) {
      return Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: p.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appStrings.onboardingMessagingConnected(platform.label),
              style: TextStyle(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    if (qr != null) return MessagingQrPanel(qrState: qr!);
    if (status.isConnecting) {
      return Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appStrings.onboardingMessagingWaiting(platform.label),
              style: TextStyle(color: p.textSecondary),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Every messaging app the server supports, searchable, one row each.
class _PlatformList extends StatelessWidget {
  const _PlatformList({
    required this.platforms,
    required this.selectedId,
    required this.isConnected,
    required this.onSelect,
  });

  final List<MessagingPlatformDescriptor> platforms;
  final String? selectedId;
  final bool Function(String id) isConnected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      decoration: BoxDecoration(
        color: p.bgPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        padding: const EdgeInsets.all(6),
        itemCount: platforms.length,
        itemBuilder: (context, index) {
          final platform = platforms[index];
          final selected = platform.id == selectedId;
          final connected = isConnected(platform.id);
          return Material(
            color: selected
                ? p.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(platform.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: platform.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        platform.icon,
                        size: 18,
                        color: platform.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        platform.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? p.accentHover : p.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (connected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: p.success,
                      )
                    else if (selected)
                      Icon(Icons.check_rounded, size: 18, color: p.accent),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
