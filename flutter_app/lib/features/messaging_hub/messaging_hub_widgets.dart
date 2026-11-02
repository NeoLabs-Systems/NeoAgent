import 'package:flutter/material.dart';

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import '../shared_messaging/shared_messaging_widgets.dart';
import 'messaging_hub_models.dart';

/// The headline action of the page: a server-provided account, one tap away.
/// Anything else a person could do with this platform stays under Advanced.
class HubOfferCard extends StatelessWidget {
  const HubOfferCard({super.key, required this.offer});

  final HubLinkOffer offer;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final app = offer.app;
    final onUseOwn = offer.onUseOwnAccount;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: app.color.withValues(alpha: 0.24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Blended over the card, so the fade has no seam against the page.
          colors: <Color>[
            Color.alphaBlend(app.color.withValues(alpha: 0.09), p.bgCard),
            p.bgCard,
          ],
          stops: const <double>[0, 0.55],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              PlatformBadge(icon: app.icon, color: app.color, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      app.label,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (offer.accountLabel != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        offer.accountLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            appStrings.messagingHubOfferTagline,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: offer.onLink,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(appStrings.messagingHubLink(app.label)),
          ),
          if (onUseOwn == null)
            const SizedBox(height: 10)
          else ...<Widget>[
            const SizedBox(height: 4),
            HubDisclosure(
              title: appStrings.messagingHubAdvanced,
              dense: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      appStrings.sharedMessagingUseOwnHint,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onUseOwn,
                      child: Text(appStrings.sharedMessagingUseOwn),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A heading that hides what most people never need.
class HubDisclosure extends StatefulWidget {
  const HubDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.dense = false,
    this.expanded = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool dense;

  /// Opens it, for a search result that lands on something inside.
  final bool expanded;

  @override
  State<HubDisclosure> createState() => _HubDisclosureState();
}

class _HubDisclosureState extends State<HubDisclosure> {
  late bool _open = widget.expanded;

  @override
  void didUpdateWidget(HubDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: widget.dense ? 8 : 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.dense ? p.textMuted : p.textPrimary,
                          fontSize: widget.dense ? 12.5 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: widget.dense ? 18 : 22,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open ? widget.child : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Rows sharing one rounded surface, split by hairlines.
class HubGroup extends StatelessWidget {
  const HubGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i += 1) ...<Widget>[
            if (i > 0) Divider(height: 1, indent: 68, color: p.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One app. The row itself is the action while there is something to do, and
/// everything else about a connected app waits behind its menu.
class HubAppRow extends StatelessWidget {
  const HubAppRow({super.key, required this.app});

  final HubApp app;

  (String, Color) _line(NeoAgentPalette p) {
    final identity = app.identity;
    return switch (app.state) {
      HubAppState.live => (
        identity == null
            ? appStrings.messagingHubConnected
            : appStrings.messagingHubConnectedAs(identity),
        p.success,
      ),
      HubAppState.connecting => (appStrings.messagingHubConnecting, p.warning),
      HubAppState.attention => (appStrings.messagingHubNotRunning, p.warning),
      HubAppState.disabled => (appStrings.messagingHubDisabled, p.textMuted),
      HubAppState.available => (app.subtitle, p.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final (line, lineColor) = _line(p);
    // A shared account is the admin's to bring back, so there is nothing here
    // for the person to press.
    final tappable =
        app.state == HubAppState.available ||
        (app.state == HubAppState.attention && !app.isShared);
    return InkWell(
      onTap: tappable ? app.onConnect : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: <Widget>[
            PlatformBadge(icon: app.icon, color: app.color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (app.isShared) ...<Widget>[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.dns_outlined,
                          size: 13,
                          color: p.textMuted,
                          semanticLabel: appStrings.sharedMessagingBadge,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (app.state != HubAppState.available &&
                          app.state != HubAppState.disabled) ...<Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: lineColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ..._trailing(p),
          ],
        ),
      ),
    );
  }

  List<Widget> _trailing(NeoAgentPalette p) {
    return <Widget>[
      if (app.state == HubAppState.available)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(Icons.add_rounded, size: 20, color: p.accentHover),
        ),
      if (app.state == HubAppState.attention && !app.isShared)
        Text(
          appStrings.messagingHubReconnect,
          style: TextStyle(
            color: p.accentHover,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (app.menu.isNotEmpty)
        PopupMenuButton<HubMenuAction>(
          tooltip: appStrings.messagingHubManage(app.label),
          icon: Icon(Icons.more_horiz_rounded, size: 20, color: p.textMuted),
          onSelected: (action) => action.onSelected(),
          itemBuilder: (context) => <PopupMenuEntry<HubMenuAction>>[
            for (final action in app.menu)
              PopupMenuItem<HubMenuAction>(
                value: action,
                child: Text(
                  action.label,
                  style: action.destructive ? TextStyle(color: p.danger) : null,
                ),
              ),
          ],
        ),
    ];
  }
}

/// A small heading above a section.
class HubSectionLabel extends StatelessWidget {
  const HubSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: paletteOf(context).textMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
