import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'messaging_hub_models.dart';
import 'messaging_hub_widgets.dart';

/// How many apps show before "Show all": enough for most people.
const int hubFeaturedAppCount = 4;

/// Settings › Platforms. It answers one question at a time: what is connected,
/// what is the easiest thing to connect, and everything else if you go looking.
class MessagingHub extends StatelessWidget {
  const MessagingHub({
    super.key,
    required this.agentName,
    required this.apps,
    required this.offers,
    required this.moreSettings,
    this.pendingQr,
    this.moreSettingsExpanded = false,
  });

  final String agentName;
  final List<HubApp> apps;
  final List<HubLinkOffer> offers;

  /// Group chat behaviour and recent activity, folded away.
  final List<Widget> moreSettings;
  final bool moreSettingsExpanded;
  final Widget? pendingQr;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final mine = apps.where((app) => app.isMine).toList(growable: false)
      ..sort((a, b) => a.state.index.compareTo(b.state.index));
    final offered = offers.map((offer) => offer.app.id).toSet();
    final others = apps
        .where((app) => !app.isMine && !offered.contains(app.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          appStrings.messagingHubTitle(agentName),
          style: GoogleFonts.geist(
            color: p.textPrimary,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          appStrings.messagingHubSubtitle,
          style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 24),
        if (pendingQr != null) ...<Widget>[
          pendingQr!,
          const SizedBox(height: 20),
        ],
        if (mine.isNotEmpty) ...<Widget>[
          HubSectionLabel(appStrings.messagingHubYourApps),
          HubGroup(
            children: <Widget>[
              for (final app in mine)
                HubAppRow(key: ValueKey(app.id), app: app),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (offers.isNotEmpty) ...<Widget>[
          _OfferGrid(offers: offers),
          const SizedBox(height: 24),
        ],
        if (others.isNotEmpty) HubAppCatalog(apps: others, titled: true),
        const SizedBox(height: 12),
        HubDisclosure(
          title: appStrings.messagingHubMoreSettings,
          subtitle: appStrings.messagingHubMoreSettingsHint,
          expanded: moreSettingsExpanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final section in moreSettings) ...<Widget>[
                const SizedBox(height: 8),
                section,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferGrid extends StatelessWidget {
  const _OfferGrid({required this.offers});

  final List<HubLinkOffer> offers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (offers.length > 1 && constraints.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < offers.length; i += 1) ...<Widget>[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: HubOfferCard(offer: offers[i])),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < offers.length; i += 1) ...<Widget>[
              if (i > 0) const SizedBox(height: 14),
              HubOfferCard(offer: offers[i]),
            ],
          ],
        );
      },
    );
  }
}

/// The apps a person could add: a short list, the rest one tap away and
/// searchable. Search only appears once the list is long enough to need it.
class HubAppCatalog extends StatefulWidget {
  const HubAppCatalog({super.key, required this.apps, this.titled = false});

  final List<HubApp> apps;
  final bool titled;

  @override
  State<HubAppCatalog> createState() => _HubAppCatalogState();
}

class _HubAppCatalogState extends State<HubAppCatalog> {
  bool _showAll = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final query = _query.toLowerCase();
    final overflow = widget.apps.length > hubFeaturedAppCount;
    final visible = !_showAll
        ? widget.apps.take(hubFeaturedAppCount).toList(growable: false)
        : widget.apps
              .where((app) => app.label.toLowerCase().contains(query))
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.titled) HubSectionLabel(appStrings.messagingHubAddApp),
        if (_showAll) ...<Widget>[
          TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: appStrings.onboardingSearchApps,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              appStrings.noPlatformsMatch,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
          )
        else
          HubGroup(
            children: <Widget>[
              for (final app in visible)
                HubAppRow(key: ValueKey(app.id), app: app),
            ],
          ),
        if (overflow)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _showAll = !_showAll;
                _query = '';
              }),
              child: Text(
                _showAll
                    ? appStrings.messagingHubShowFewer
                    : appStrings.messagingHubShowAll(widget.apps.length),
              ),
            ),
          ),
      ],
    );
  }
}
