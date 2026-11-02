import 'package:flutter/material.dart';

import '../../main.dart';
import '../../src/mascot/mascot_mood.dart';
import '../../src/theme/palette.dart';
import '../messaging_hub/messaging_hub.dart';
import '../messaging_hub/messaging_hub_models.dart';
import '../messaging_hub/messaging_hub_widgets.dart';
import '../shared_messaging/shared_link_flow.dart';
import '../shared_messaging/shared_messaging_widgets.dart';
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
  final VoidCallback? onBack;
  final NeoAgentController controller;

  @override
  State<OnboardingMessagingStep> createState() =>
      _OnboardingMessagingStepState();
}

class _OnboardingMessagingStepState extends State<OnboardingMessagingStep> {
  /// The platform being linked in place of the choices, once asked for.
  String? _linkingId;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // An admin can set one up between this step loading and being reached.
    _controller.refreshSharedMessagingOptions().then((_) {
      if (mounted) setState(() {});
    });
  }

  MessagingPlatformDescriptor? _platform(String? id) {
    for (final platform in messagingPlatforms) {
      if (platform.id == id) return platform;
    }
    return null;
  }

  // Every path stays on this screen or opens the platform's own setup, and a
  // failure comes back here rather than leaving the flow.
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

  /// A shared account links on this page; anything else opens its own setup.
  List<HubApp> _apps() {
    return messagingHubApps(context, _controller)
        .map((app) {
          final platform = _platform(app.id)!;
          return HubApp(
            id: app.id,
            label: app.label,
            subtitle: app.subtitle,
            icon: app.icon,
            color: app.color,
            state: app.state,
            identity: app.identity,
            isShared: app.isShared,
            onConnect: () => _connect(platform),
          );
        })
        .toList(growable: false);
  }

  List<HubLinkOffer> _offers() {
    return messagingHubOffers(context, _controller)
        .map(
          (offer) => HubLinkOffer(
            app: offer.app,
            accountLabel: offer.accountLabel,
            onLink: () => setState(() => _linkingId = offer.app.id),
            onUseOwnAccount: offer.onUseOwnAccount,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final apps = _apps();
        final mine = apps.where((app) => app.isMine).toList(growable: false);
        final live = mine.any((app) => app.state == HubAppState.live);
        final linking = _platform(_linkingId);
        final option = _controller.sharedMessagingOptions[_linkingId];
        final Widget body;
        if (linking != null && option != null) {
          body = _LinkInPlace(
            session: sharedLinkSessionFor(_controller, linking, option),
          );
        } else {
          body = _Choices(
            apps: apps,
            offers: _offers(),
            mine: mine,
            qr: _controller.pendingMessagingQr,
          );
        }
        final linkingNow = linking != null && option != null;
        return OnboardingScaffold(
          mood: live ? MascotMood.done : MascotMood.listening,
          eyebrow: appStrings.onboardingEyebrowCommunication,
          title: appStrings.onboardingMessagingTitle,
          description: appStrings.onboardingMessagingDescription,
          footer: OnboardingFooter(
            onBack: linkingNow
                ? () => setState(() => _linkingId = null)
                : widget.onBack,
            // Connecting is the action on the page; leaving is the footer's,
            // and it only turns gold once there is something to continue with.
            primary: live
                ? OnboardingPrimaryButton(
                    label: appStrings.onboardingNext,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: widget.onNext,
                  )
                : OnboardingGhostButton(
                    label: appStrings.skipForNow,
                    onPressed: widget.onNext,
                  ),
          ),
          child: body,
        );
      },
    );
  }
}

/// The link flow on the page itself, so nothing pops over the onboarding.
class _LinkInPlace extends StatelessWidget {
  const _LinkInPlace({required this.session});

  final SharedLinkSession session;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: session.platformColor.withValues(alpha: 0.28),
          ),
        ),
        child: SharedLinkFlow(session: session),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.apps,
    required this.offers,
    required this.mine,
    required this.qr,
  });

  final List<HubApp> apps;
  final List<HubLinkOffer> offers;
  final List<HubApp> mine;
  final MessagingQrState? qr;

  @override
  Widget build(BuildContext context) {
    final offered = offers.map((offer) => offer.app.id).toSet();
    final others = apps
        .where((app) => !app.isMine && !offered.contains(app.id))
        .toList(growable: false);
    final catalog = HubAppCatalog(apps: others);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (qr != null) ...<Widget>[
            MessagingQrPanel(qrState: qr!),
            const SizedBox(height: 14),
          ],
          if (mine.isNotEmpty) ...<Widget>[
            HubGroup(
              children: <Widget>[
                for (final app in mine)
                  HubAppRow(key: ValueKey(app.id), app: app),
              ],
            ),
            if (mine.any((app) => app.state == HubAppState.live)) ...<Widget>[
              const SizedBox(height: 10),
              InlineNotice(
                tone: NoticeTone.success,
                message: appStrings.onboardingMessagingAllSet,
              ),
            ],
            const SizedBox(height: 14),
          ],
          for (final offer in offers) ...<Widget>[
            HubOfferCard(offer: offer),
            const SizedBox(height: 14),
          ],
          // With a one-tap option on screen, the rest is only for those who
          // came looking; without one, the short list is the page.
          if (offers.isNotEmpty || mine.isNotEmpty)
            HubDisclosure(
              title: appStrings.onboardingMessagingOtherApps,
              child: catalog,
            )
          else
            catalog,
        ],
      ),
    );
  }
}
