import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'shared_messaging_models.dart';
import 'shared_messaging_widgets.dart';

/// Everything the link flow needs from the app, so it depends on nothing else.
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

  /// This person is linked on another agent; finishing here moves it.
  final bool movesExistingLink;

  /// Fires when the linked identity or the failure may have changed.
  final Listenable updates;
  final Future<SharedMessagingLink> Function() startLink;

  /// Who this agent is linked as, or null while it is not.
  final String? Function() linkedIdentity;
  final String? Function() failure;
  final String Function(Object error) describeError;
}

/// Linking through an instance-wide account: a code the moment this appears,
/// then who you linked as. Asking for it is the choice, so there is nothing to
/// pick here; it stays until [onDone], whatever updates arrive in between.
class SharedLinkFlow extends StatefulWidget {
  const SharedLinkFlow({
    super.key,
    required this.session,
    required this.onDone,
  });

  final SharedLinkSession session;
  final VoidCallback onDone;

  @override
  State<SharedLinkFlow> createState() => _SharedLinkFlowState();
}

class _SharedLinkFlowState extends State<SharedLinkFlow> {
  SharedMessagingLink? _link;
  bool _starting = false;
  String? _error;
  Timer? _ticker;

  SharedLinkSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.updates.addListener(_refresh);
    _start();
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

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final identity = link == null ? null : _session.linkedIdentity();
    final error = _error;
    final Widget body;
    if (identity != null) {
      _ticker?.cancel();
      body = _LinkedView(
        session: _session,
        identity: identity,
        onDone: widget.onDone,
      );
    } else if (link != null) {
      body = _CodeView(
        session: _session,
        link: link,
        starting: _starting,
        onNewCode: _start,
      );
    } else if (error != null) {
      body = InlineNotice(
        tone: NoticeTone.danger,
        message: error,
        actionLabel: appStrings.sharedAccountRetry,
        onAction: _start,
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: body,
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
        if (session.movesExistingLink) ...<Widget>[
          InlineNotice(
            tone: NoticeTone.info,
            message: appStrings.sharedMessagingMovesLink(session.platformLabel),
          ),
          const SizedBox(height: 12),
        ],
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
