import 'dart:async';

import 'package:flutter/material.dart';

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'shared_account_card.dart';
import 'shared_accounts_repository.dart';
import 'shared_messaging_models.dart';
import 'shared_messaging_widgets.dart';

/// How a platform is drawn; the app owns its catalogue of platforms.
class SharedPlatformLook {
  const SharedPlatformLook({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

/// Admin › Messaging: the instance-wide accounts people on this server can link
/// to. Status comes from the server, so `neoagent messaging` shows up here too.
class SharedAccountsPanel extends StatefulWidget {
  const SharedAccountsPanel({
    super.key,
    required this.repository,
    required this.lookFor,
    required this.describeError,
    this.pollInterval = const Duration(seconds: 3),
  });

  final SharedAccountsRepository repository;
  final SharedPlatformLook Function(String platform) lookFor;
  final String Function(Object error) describeError;
  final Duration pollInterval;

  @override
  State<SharedAccountsPanel> createState() => _SharedAccountsPanelState();
}

class _SharedAccountsPanelState extends State<SharedAccountsPanel> {
  List<SharedAccount>? _accounts;
  String? _loadError;
  Timer? _poll;
  int _pendingWrites = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // A QR code rotates and a connection comes up on its own while this is open.
    _poll = Timer.periodic(widget.pollInterval, (_) => _refreshQuietly());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final accounts = await widget.repository.fetch();
      if (mounted) setState(() => _accounts = accounts);
    } catch (error) {
      if (mounted) setState(() => _loadError = widget.describeError(error));
    }
  }

  // A reply that started before a write would put old values back.
  Future<void> _refreshQuietly() async {
    if (_accounts == null || _pendingWrites > 0) return;
    try {
      final accounts = await widget.repository.fetch();
      if (mounted && _pendingWrites == 0) setState(() => _accounts = accounts);
    } catch (_) {
      // The next tick tries again; failed writes report themselves.
    }
  }

  Future<String?> _write(Future<List<SharedAccount>> Function() action) async {
    _pendingWrites += 1;
    try {
      final accounts = await action();
      if (mounted) setState(() => _accounts = accounts);
      return null;
    } catch (error) {
      return widget.describeError(error);
    } finally {
      _pendingWrites -= 1;
    }
  }

  Future<void> _remove(String platform, String label) async {
    final error = await _write(() => widget.repository.remove(platform));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(error ?? appStrings.sharedAccountRemoved(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final accounts = _accounts;
    final error = _loadError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          appStrings.sharedAccountsTitle,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          appStrings.sharedAccountsIntro,
          style: TextStyle(
            color: p.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          InlineNotice(
            tone: NoticeTone.danger,
            message: error,
            actionLabel: appStrings.sharedAccountRetry,
            onAction: _load,
          )
        else if (accounts == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else
          for (final account in accounts) ...<Widget>[
            _card(account),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _card(SharedAccount account) {
    final look = widget.lookFor(account.platform);
    return SharedAccountCard(
      key: ValueKey<String>(account.platform),
      account: account,
      label: look.label,
      icon: look.icon,
      color: look.color,
      onChange: (changes) =>
          _write(() => widget.repository.save(account.platform, changes)),
      onRemove: () => _remove(account.platform, look.label),
    );
  }
}
