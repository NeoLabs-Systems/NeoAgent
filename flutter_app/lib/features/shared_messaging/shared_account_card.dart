import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../src/l10n/app_language.dart';
import '../../src/theme/palette.dart';
import 'shared_messaging_models.dart';
import 'shared_messaging_widgets.dart';

/// Runs one change on the server; resolves to an error message, or null if saved.
typedef SharedAccountAction =
    Future<String?> Function(SharedAccountChanges changes);

/// One platform's instance-wide account: what it is doing now, the one thing
/// to do next, and its rules. Setup stays out of sight until it is asked for.
class SharedAccountCard extends StatefulWidget {
  const SharedAccountCard({
    super.key,
    required this.account,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChange,
    required this.onRemove,
  });

  final SharedAccount account;
  final String label;
  final IconData icon;
  final Color color;

  final SharedAccountAction onChange;
  final Future<void> Function() onRemove;

  @override
  State<SharedAccountCard> createState() => _SharedAccountCardState();
}

class _SharedAccountCardState extends State<SharedAccountCard> {
  final TextEditingController _token = TextEditingController();
  bool _editingCredentials = false;
  bool _tokenVisible = false;
  bool _busy = false;
  String? _error;

  SharedAccount get _account => widget.account;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _apply(SharedAccountChanges changes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onChange(changes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null && changes.botToken != null) {
        _token.clear();
        _editingCredentials = false;
      }
    });
  }

  Future<void> _submitToken() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _error = appStrings.sharedAccountTokenMissing);
      return;
    }
    await _apply(
      SharedAccountChanges(botToken: token, enabled: true, reconnect: true),
    );
  }

  void _connect() {
    _apply(const SharedAccountChanges(enabled: true, reconnect: true));
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appStrings.sharedAccountRemoveTitle(widget.label)),
        content: Text(appStrings.sharedAccountRemoveBody(_account.linkedUsers)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(appStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: paletteOf(dialogContext).danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(appStrings.sharedAccountRemove),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onRemove();
  }

  (String, Color) _status(NeoAgentPalette p) {
    return switch (_account.state) {
      SharedAccountState.live => (
        appStrings.sharedAccountStatusLive,
        p.success,
      ),
      SharedAccountState.starting => (
        appStrings.sharedAccountStatusStarting,
        p.warning,
      ),
      SharedAccountState.awaitingScan => (appStrings.awaitingScan, p.warning),
      SharedAccountState.failed => (
        appStrings.sharedAccountStatusFailed,
        p.danger,
      ),
      SharedAccountState.off => (
        appStrings.sharedAccountStatusOff,
        p.textMuted,
      ),
      SharedAccountState.notSetUp => (
        appStrings.sharedAccountStatusNotSetUp,
        p.textMuted,
      ),
    };
  }

  String _subtitle() {
    if (!_account.configured) {
      return _account.usesToken
          ? appStrings.sharedAccountTelegramPitch
          : appStrings.sharedAccountWhatsappPitch;
    }
    final account = _account.accountLabel;
    final linked = appStrings.sharedAccountLinkedCount(_account.linkedUsers);
    return account == null ? linked : '$account · $linked';
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final (statusLabel, statusColor) = _status(p);
    final showTokenForm =
        _account.usesToken && (_editingCredentials || !_account.configured);
    return Container(
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _account.state == SharedAccountState.live
              ? widget.color.withValues(alpha: 0.4)
              : p.border,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              // On a phone the title needs the width, so the status moves under it.
              final compact = constraints.maxWidth < 420;
              final chip = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: StatusChip(label: statusLabel, color: statusColor),
              );
              return Row(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: <Widget>[
                  PlatformBadge(icon: widget.icon, color: widget.color),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(),
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        if (compact) ...<Widget>[
                          const SizedBox(height: 8),
                          chip,
                        ],
                      ],
                    ),
                  ),
                  if (!compact) ...<Widget>[const SizedBox(width: 10), chip],
                  if (_account.configured) _overflowMenu(),
                ],
              );
            },
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            InlineNotice(tone: NoticeTone.danger, message: _error!),
          ],
          ..._nextStep(showTokenForm),
          if (_account.configured) ...<Widget>[
            const SizedBox(height: 12),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 6),
            SettingSwitchRow(
              title: appStrings.sharedAccountAvailable,
              subtitle: appStrings.sharedAccountAvailableHint,
              value: _account.available,
              onChanged: _busy
                  ? null
                  : (value) => _apply(SharedAccountChanges(available: value)),
            ),
            SettingSwitchRow(
              title: appStrings.sharedAccountAllowPersonal,
              subtitle: appStrings.sharedAccountAllowPersonalHint,
              value: _account.allowPersonal,
              onChanged: _busy
                  ? null
                  : (value) =>
                        _apply(SharedAccountChanges(allowPersonal: value)),
            ),
          ],
        ],
      ),
    );
  }

  /// The body answers "what do I do now?", so there is one primary action.
  List<Widget> _nextStep(bool showTokenForm) {
    final state = _account.state;
    final widgets = <Widget>[
      if (state == SharedAccountState.failed)
        InlineNotice(
          tone: NoticeTone.danger,
          message: _account.usesToken
              ? appStrings.sharedAccountTelegramFailed
              : appStrings.sharedAccountWhatsappFailed,
          actionLabel: _account.usesToken
              ? null
              : appStrings.sharedAccountShowQr,
          onAction: _account.usesToken || _busy ? null : _connect,
        ),
      if (showTokenForm ||
          (state == SharedAccountState.failed && _account.usesToken))
        _TokenSetup(
          controller: _token,
          firstTime: !_account.configured,
          visible: _tokenVisible,
          busy: _busy,
          onToggleVisible: () => setState(() => _tokenVisible = !_tokenVisible),
          onSubmit: _submitToken,
          onCancel: _account.configured && state != SharedAccountState.failed
              ? () => setState(() {
                  _editingCredentials = false;
                  _token.clear();
                  _error = null;
                })
              : null,
        ),
      if (state == SharedAccountState.notSetUp && !_account.usesToken)
        _WhatsappSetup(busy: _busy, onStart: _connect),
      if (state == SharedAccountState.awaitingScan && _account.qr != null)
        _WhatsappScan(qr: _account.qr!),
      if (state == SharedAccountState.starting)
        const LinearProgressIndicator(minHeight: 2),
      if (state == SharedAccountState.off)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy ? null : _connect,
            child: Text(appStrings.sharedAccountTurnOn),
          ),
        ),
    ];
    return <Widget>[
      for (final widget in widgets) ...<Widget>[
        const SizedBox(height: 14),
        widget,
      ],
    ];
  }

  Widget _overflowMenu() {
    final enabled = _account.enabled;
    return PopupMenuButton<_CardAction>(
      tooltip: appStrings.sharedAccountMore,
      enabled: !_busy,
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: (action) {
        switch (action) {
          case _CardAction.reconnect:
            _connect();
          case _CardAction.replaceToken:
            setState(() => _editingCredentials = true);
          case _CardAction.turnOff:
            _apply(const SharedAccountChanges(enabled: false));
          case _CardAction.remove:
            _confirmRemove();
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_CardAction>>[
        if (enabled)
          PopupMenuItem(
            value: _CardAction.reconnect,
            child: Text(appStrings.sharedAccountReconnect),
          ),
        if (_account.usesToken)
          PopupMenuItem(
            value: _CardAction.replaceToken,
            child: Text(appStrings.sharedAccountReplaceToken),
          ),
        if (enabled)
          PopupMenuItem(
            value: _CardAction.turnOff,
            child: Text(appStrings.sharedAccountTurnOff),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CardAction.remove,
          child: Text(
            appStrings.sharedAccountRemove,
            style: TextStyle(color: paletteOf(context).danger),
          ),
        ),
      ],
    );
  }
}

enum _CardAction { reconnect, replaceToken, turnOff, remove }

class _TokenSetup extends StatelessWidget {
  const _TokenSetup({
    required this.controller,
    required this.firstTime,
    required this.visible,
    required this.busy,
    required this.onToggleVisible,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool firstTime;
  final bool visible;
  final bool busy;
  final VoidCallback onToggleVisible;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: appStrings.sharedAccountBotToken,
        hintText: '123456:ABC-DEF…',
        isDense: true,
        suffixIcon: IconButton(
          tooltip: visible
              ? appStrings.sharedAccountHideToken
              : appStrings.sharedAccountShowToken,
          onPressed: onToggleVisible,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
        ),
      ),
    );
    final actions = Wrap(
      spacing: 8,
      children: <Widget>[
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(appStrings.sharedAccountConnect),
        ),
        if (onCancel != null)
          TextButton(onPressed: onCancel, child: Text(appStrings.cancel)),
      ],
    );
    if (!firstTime) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[field, const SizedBox(height: 10), actions],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SetupStep(
          number: 1,
          title: appStrings.sharedAccountTelegramStepBot,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => url_launcher.launchUrl(
                Uri.parse('https://t.me/BotFather'),
                mode: url_launcher.LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('@BotFather'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SetupStep(
          number: 2,
          title: appStrings.sharedAccountTelegramStepToken,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[field, const SizedBox(height: 10), actions],
          ),
        ),
      ],
    );
  }
}

class _WhatsappSetup extends StatelessWidget {
  const _WhatsappSetup({required this.busy, required this.onStart});

  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InlineNotice(
          tone: NoticeTone.warning,
          message: appStrings.sharedAccountWhatsappWarning,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: Text(appStrings.sharedAccountShowQr),
          ),
        ),
      ],
    );
  }
}

class _WhatsappScan extends StatelessWidget {
  const _WhatsappScan({required this.qr});

  final String qr;

  @override
  Widget build(BuildContext context) {
    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SetupStep(number: 1, title: appStrings.sharedAccountScanStepOpen),
        const SizedBox(height: 10),
        SetupStep(number: 2, title: appStrings.sharedAccountScanStepDevices),
        const SizedBox(height: 10),
        SetupStep(number: 3, title: appStrings.sharedAccountScanStepPoint),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: ScanCode(data: qr)),
              const SizedBox(height: 14),
              steps,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ScanCode(data: qr),
            const SizedBox(width: 20),
            Expanded(child: steps),
          ],
        );
      },
    );
  }
}
