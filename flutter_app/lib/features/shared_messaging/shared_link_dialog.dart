import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'shared_messaging_models.dart';
import 'shared_messaging_widgets.dart';

enum SharedLinkOutcome { linked, useOwnAccount }

/// Everything the dialog needs from the app, so it depends on nothing else.
class SharedLinkSession {
  const SharedLinkSession({
    required this.platformLabel,
    required this.platformIcon,
    required this.platformColor,
    required this.option,
    required this.movesExistingLink,
    required this.updates,
    required this.startLink,
    required this.linkedIdentity,
    required this.failure,
    required this.describeError,
  });

  final String platformLabel;
  final IconData platformIcon;
  final Color platformColor;
  final SharedMessagingOption option;

  /// This person is linked on another agent; linking here moves it.
  final bool movesExistingLink;

  /// Fires when the linked identity or the failure may have changed.
  final Listenable updates;
  final Future<SharedMessagingLink> Function() startLink;

  /// Who this agent is linked as, or null while it is not.
  final String? Function() linkedIdentity;
  final String? Function() failure;
  final String Function(Object error) describeError;
}

Future<SharedLinkOutcome?> showSharedLinkDialog(
  BuildContext context,
  SharedLinkSession session,
) {
  return showDialog<SharedLinkOutcome>(
    context: context,
    builder: (_) => SharedLinkDialog(session: session),
  );
}

/// Connecting through an instance-wide account: pick it (or your own account),
/// send a one-time code from the app you want to use, see who you linked as.
class SharedLinkDialog extends StatefulWidget {
  const SharedLinkDialog({super.key, required this.session});

  final SharedLinkSession session;

  @override
  State<SharedLinkDialog> createState() => _SharedLinkDialogState();
}

class _SharedLinkDialogState extends State<SharedLinkDialog> {
  SharedMessagingLink? _link;
  bool _starting = false;
  String? _error;
  Timer? _ticker;

  SharedLinkSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.updates.addListener(_refresh);
    // Without a choice to make, the first screen would be a single button.
    if (!_session.option.personalAllowed && !_session.movesExistingLink) {
      _start();
    }
  }

  @override
  void dispose() {
    _session.updates.removeListener(_refresh);
    _ticker?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final link = await _session.startLink();
      if (!mounted) return;
      _ticker?.cancel();
      // Only the countdown needs this, and only while a code is on screen.
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
      setState(() => _link = link);
    } catch (error) {
      if (mounted) setState(() => _error = _session.describeError(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _close([SharedLinkOutcome? outcome]) {
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final identity = link == null ? null : _session.linkedIdentity();
    final Widget body;
    if (identity != null) {
      _ticker?.cancel();
      body = _LinkedView(
        session: _session,
        identity: identity,
        onDone: () => _close(SharedLinkOutcome.linked),
      );
    } else if (link != null) {
      body = _CodeView(
        session: _session,
        link: link,
        starting: _starting,
        onNewCode: _start,
      );
    } else if (_starting && !_session.option.personalAllowed) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    } else {
      body = _ChooserView(
        session: _session,
        starting: _starting,
        onUseShared: _start,
        onUseOwn: () => _close(SharedLinkOutcome.useOwnAccount),
      );
    }
    final error = _error;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DialogHeader(session: _session, onClose: _close),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: body,
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                InlineNotice(tone: NoticeTone.danger, message: error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.session, required this.onClose});

  final SharedLinkSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Row(
      children: <Widget>[
        PlatformBadge(
          icon: session.platformIcon,
          color: session.platformColor,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            appStrings.sharedMessagingTitle(session.platformLabel),
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    );
  }
}

class _ChooserView extends StatelessWidget {
  const _ChooserView({
    required this.session,
    required this.starting,
    required this.onUseShared,
    required this.onUseOwn,
  });

  final SharedLinkSession session;
  final bool starting;
  final VoidCallback onUseShared;
  final VoidCallback onUseOwn;

  @override
  Widget build(BuildContext context) {
    final account =
        session.option.accountLabel ?? appStrings.sharedMessagingThisServer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ChoiceCard(
          icon: Icons.bolt_rounded,
          highlighted: true,
          title: appStrings.sharedMessagingUseShared,
          subtitle: appStrings.sharedMessagingUseSharedHint(account),
          busy: starting,
          onTap: starting ? null : onUseShared,
        ),
        if (session.option.personalAllowed) ...<Widget>[
          const SizedBox(height: 10),
          _ChoiceCard(
            icon: Icons.person_outline_rounded,
            title: appStrings.sharedMessagingUseOwn,
            subtitle: appStrings.sharedMessagingUseOwnHint,
            onTap: starting ? null : onUseOwn,
          ),
        ],
        if (session.movesExistingLink) ...<Widget>[
          const SizedBox(height: 12),
          InlineNotice(
            tone: NoticeTone.info,
            message: appStrings.sharedMessagingMovesLink(session.platformLabel),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final radius = BorderRadius.circular(14);
    return Material(
      color: highlighted
          ? p.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: highlighted ? p.accent.withValues(alpha: 0.45) : p.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: highlighted ? p.accentHover : p.textSecondary,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({
    required this.session,
    required this.link,
    required this.starting,
    required this.onNewCode,
  });

  final SharedLinkSession session;
  final SharedMessagingLink link;
  final bool starting;
  final VoidCallback onNewCode;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final url = link.url;
    final remaining = link.expiresAt.difference(DateTime.now());
    final expired = remaining <= Duration.zero;
    final failure = session.failure();
    // Scanning only helps when this screen is not the phone itself.
    final showScan =
        url != null && !expired && MediaQuery.sizeOf(context).width >= 560;
    final account = session.option.accountLabel ?? session.platformLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          url == null
              ? appStrings.sharedMessagingSendCode(account)
              : appStrings.sharedMessagingOpenAndSend(session.platformLabel),
          style: TextStyle(
            color: p.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        if (showScan) ...<Widget>[
          Center(child: ScanCode(data: url)),
          const SizedBox(height: 8),
          Text(
            appStrings.sharedMessagingScanHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
        ],
        if (url != null && !expired) ...<Widget>[
          FilledButton.icon(
            onPressed: () => url_launcher.launchUrl(
              Uri.parse(url),
              mode: url_launcher.LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: Text(
              appStrings.sharedMessagingOpenApp(session.platformLabel),
            ),
          ),
          const SizedBox(height: 12),
        ],
        LinkCodeTile(code: link.code, enabled: !expired),
        const SizedBox(height: 14),
        if (failure != null)
          InlineNotice(
            tone: NoticeTone.danger,
            message: failure,
            actionLabel: appStrings.sharedMessagingNewCode,
            onAction: starting ? null : onNewCode,
          )
        else if (expired)
          InlineNotice(
            tone: NoticeTone.warning,
            message: appStrings.sharedMessagingCodeExpired,
            actionLabel: appStrings.sharedMessagingNewCode,
            onAction: starting ? null : onNewCode,
          )
        else
          _WaitingRow(remaining: remaining),
        const SizedBox(height: 12),
        Text(
          appStrings.sharedMessagingCodeNote,
          style: TextStyle(color: p.textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: <Widget>[
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            appStrings.sharedMessagingWaiting,
            style: TextStyle(color: p.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          '${remaining.inMinutes}:$seconds',
          style: TextStyle(
            color: p.textMuted,
            fontSize: 12.5,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LinkedView extends StatelessWidget {
  const _LinkedView({
    required this.session,
    required this.identity,
    required this.onDone,
  });

  final SharedLinkSession session;
  final String identity;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 6),
        Icon(Icons.check_circle_rounded, size: 44, color: p.success),
        const SizedBox(height: 12),
        Text(
          appStrings.sharedMessagingLinked(session.platformLabel, identity),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          appStrings.sharedMessagingLinkedHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onDone,
          child: Text(appStrings.sharedMessagingDone),
        ),
      ],
    );
  }
}
